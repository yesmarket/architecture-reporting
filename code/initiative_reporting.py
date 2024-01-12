import os
import boto3
from base64 import b64decode
import requests
from bs4 import BeautifulSoup
import pandas as pd
from datetime import datetime
from datetime import date
import json

def lambda_handler(event, context):

    auth_header_expected = get_secret("AUTHORIZATION_HEADER")
    
    if "headers" in event:

        auth_header_actual = ""
        if "authorization" in event["headers"]:
            auth_header_actual = event["headers"]["authorization"]
            
        if auth_header_expected != auth_header_actual:
            return {
                'statusCode': 401
            }
    else:
        
        if "detail-type" in event and event["detail-type"] != "Scheduled Event":
            return {
                'statusCode': 401
            }
        
    rollover_elastic_index()

    space_id = os.environ["CONFLUENCE_SPACE_ID"]

    init_ids = get_confluence_ids(space_id, "initiative")
    init_props = get_props(space_id, "initiative", init_ids)
    init_df = convert_to_dataframe(init_props)
    write_docs_to_elastic(init_df)
    #send_report_via_elastic_watcher()

    return {
        'statusCode': 200,
        'body': json.dumps('succcess!')
    }

def rollover_elastic_index():
    
    elastic_url = os.environ["ELASTIC_URL"]
    elastic_datastream = os.environ["ELASTIC_DATASTREAM"]
    elastic_api_key = get_secret("ELASTIC_API_KEY")
    
    headers = {
        'Content-type': 'application/json', 
        'Authorization': f'ApiKey {elastic_api_key}'
    }
    
    # rollover data stream
    elastic_rollover_url=f'{elastic_url}/{elastic_datastream}/_rollover'
    rollover_response=requests.post(elastic_rollover_url, headers=headers)
    
    # delete old index
    rollover_response_json=rollover_response.json()
    elastic_new_index=rollover_response_json["new_index"]
    elastic_old_index=rollover_response_json["old_index"]
    
    elastic_delete_old_index_url=f'{elastic_url}/{elastic_old_index}'
    delete_response=requests.delete(elastic_delete_old_index_url, headers=headers)

def get_confluence_ids(space, label):
    
    confluence_url = os.environ["CONFLUENCE_URL"]
    confluence_email = os.environ["CONFLUENCE_EMAIL"]
    confluence_token = get_secret("CONFLUENCE_TOKEN")
    
    confluence_pages_url=f'{confluence_url}/wiki/rest/api/search?cql=type=page and space={space} and label={label}'

    ids=[]

    start=0
    limit=25
    
    while True:

        pages_request=requests.get(confluence_pages_url, auth=(confluence_email, confluence_token))

        pages = pages_request.json()

        for result in pages["results"]:
            ids.append(result["content"]["id"])

        start=pages["start"]
        limit=pages["limit"]
        totalSize=pages["totalSize"]

        if start+limit>=totalSize:
            break

        confluence_pages_url=f'{confluence_url}/wiki/{pages["_links"]["next"]}'
    
    return ids

def get_props(space, label, ids):

    confluence_url = os.environ["CONFLUENCE_URL"]
    confluence_email = os.environ["CONFLUENCE_EMAIL"]
    confluence_token = get_secret("CONFLUENCE_TOKEN")
    
    props=[]

    for id in ids:

        confluence_page_properties_url=f'{confluence_url}/wiki/rest/masterdetail/1.0/detailssummary/lines?cql=type=page and label={label} and Id={id}&spaceKey={space}'
        page_properties_request=requests.get(confluence_page_properties_url, auth=(confluence_email, confluence_token))
        data = page_properties_request.json()

        if data['totalPages'] > 0:

            renderedHeadings=data["renderedHeadings"]
            details=data["detailLines"][0]["details"]

            page_properties={}
            page_properties['title']=data["detailLines"][0]['title']

            for i in range(0, len(renderedHeadings)):
                heading=BeautifulSoup(renderedHeadings[i], "html.parser")
                detail=BeautifulSoup(details[i], "html.parser")
                page_properties[heading.get_text().strip()]=detail.get_text().strip()

            props.append(page_properties)

    return props

def convert_to_dataframe(props):
    
    df = pd.DataFrame(props)

    df['Date Created'] = pd.to_datetime(df['Date Created'].str.strip(), errors='coerce')
    df['Planned BRD Start Date'] = pd.to_datetime(df['Planned BRD Start Date'].str.strip(), errors='coerce')
    df['Planned BRD End Date (Gate 2)'] = pd.to_datetime(df['Planned BRD End Date (Gate 2)'].str.strip(), errors='coerce')
    df['Actual BRD Start Date'] = pd.to_datetime(df['Actual BRD Start Date'].str.strip(), errors='coerce')
    df['Actual BRD End Date (Gate 2)'] = pd.to_datetime(df['Actual BRD End Date (Gate 2)'].str.strip(), errors='coerce')
    df['Planned Solution Design Start Date (Gate 3)'] = pd.to_datetime(df['Planned Solution Design Start Date (Gate 3)'].str.strip(), errors='coerce')
    df['Planned Solution Design End Date'] = pd.to_datetime(df['Planned Solution Design End Date'].str.strip(), errors='coerce')
    df['Actual Solution Design Start Date'] = pd.to_datetime(df['Actual Solution Design Start Date'].str.strip(), errors='coerce')
    df['Actual Solution Design End Date (Gate 3)'] = pd.to_datetime(df['Actual Solution Design End Date (Gate 3)'].str.strip(), errors='coerce')
    df['Budget'] = df['Budget'].replace('[\$,]', '', regex=True)

    return df

def write_docs_to_elastic(df):
    
    elastic_url = os.environ["ELASTIC_URL"]
    elastic_datastream = os.environ["ELASTIC_DATASTREAM"]
    elastic_url=f'{elastic_url}/{elastic_datastream}/_doc'
    elastic_api_key = get_secret("ELASTIC_API_KEY")

    headers = {
        'Content-type': 'application/json', 
        'Authorization': f'ApiKey {elastic_api_key}'
    }
            
    for i, row in df.iterrows():

        executive_sponsors = [x.strip() for x in row['Executive Sponsor(s)'].split(',')]
        business_owners = [x.strip() for x in row['Business Owner(s)'].split(',')]
        delivery_managers = [x.strip() for x in row['Delivery Manager(s)'].split(',')]
        products = [x.strip() for x in row['Product(s) Impacted'].split(',')]
        external_vendors = [x.strip() for x in row['External Vendor(s)'].split(',')]
        
        display_date = row['Date Created']
        if type(row['Actual BRD Start Date']) is not pd._libs.tslibs.nattype.NaTType and row['Actual BRD Start Date'].date() <= date.today():
            display_date = row['Actual BRD Start Date']
        elif type(row['Planned BRD Start Date']) is not pd._libs.tslibs.nattype.NaTType and row['Planned BRD Start Date'].date() <= date.today():
            display_date = row['Planned BRD Start Date']
        
        gate = 1
        if row['Status'] == 'PENDING APPROVAL' or row['Status'] == 'BUSINESS REQUIREMENTS DEFINITION':
            gate = 1
        elif row['Status'] == 'BRD ENDORSED - GATE 2' or row['Status'] == 'SOLUTION DESIGN':
            gate = 2
        elif row['Status'] == 'SOL DESIGN ENDORSED - GATE 3' or row['Status'] == 'IN DEVELOPMENT':
            gate = 3
        elif row['Status'] == 'READY FOR TEST - GATE 4':
            gate = 4
        elif row['Status'] == 'CAB - GATE 5':
            gate = 5
        elif row['Status'] != 'LIVE' and row['Status'] != 'INITATIVE COMPLETE':
            if ((type(row['Actual Solution Design End Date (Gate 3)']) is not pd._libs.tslibs.nattype.NaTType and row['Actual Solution Design End Date (Gate 3)'].date() >= date.today()) or (type(row['Planned Solution Design End Date']) is not pd._libs.tslibs.nattype.NaTType and row['Planned Solution Design End Date'].date()  >= date.today())):
                gate = 3
            elif ((type(row['Actual BRD Start Date']) is not pd._libs.tslibs.nattype.NaTType and row['Actual BRD Start Date'].date() >= date.today()) or (type(row['Planned BRD Start Date']) is not pd._libs.tslibs.nattype.NaTType and row['Planned BRD Start Date'].date() >= date.today())):
                gate = 2
        
        num_days_offset = 0
        if type(row['Planned Solution Design End Date']) is not pd._libs.tslibs.nattype.NaTType and type(row['Actual Solution Design End Date (Gate 3)']) is not pd._libs.tslibs.nattype.NaTType:
            num_days_offset = (row['Planned Solution Design End Date'] - row['Actual Solution Design End Date (Gate 3)']).days
        elif type(row['Planned Solution Design Start Date (Gate 3)']) is not pd._libs.tslibs.nattype.NaTType and type(row['Actual Solution Design Start Date']) is not pd._libs.tslibs.nattype.NaTType:
            num_days_offset = (row['Planned Solution Design Start Date (Gate 3)'] - row['Actual Solution Design Start Date']).days
        elif type(row['Planned BRD End Date (Gate 2)']) is not pd._libs.tslibs.nattype.NaTType and type(row['Actual BRD End Date (Gate 2)']) is not pd._libs.tslibs.nattype.NaTType:
            num_days_offset = (row['Planned BRD End Date (Gate 2)'] - row['Actual BRD End Date (Gate 2)']).days
        elif type(row['Planned BRD Start Date']) is not pd._libs.tslibs.nattype.NaTType and type(row['Actual BRD Start Date']) is not pd._libs.tslibs.nattype.NaTType:
            num_days_offset = (row['Planned BRD Start Date'] - row['Actual BRD Start Date']).days
        
        doc={
            'name': row['title'],
            'executive_sponsors': executive_sponsors,
            'business_owners': business_owners,
            'delivery_manager': delivery_managers,
            'products': products,
            'budget': row['Budget'],
            'delivery_approach': row['Delivery Approach'],
            'status': row['Status'],
            'date_created': format_date(row['Date Created']),
            'planned_brd_start_date': format_date(row['Planned BRD Start Date']),
            'planned_brd_end_date': format_date(row['Planned BRD End Date (Gate 2)']),
            'actual_brd_start_date': format_date(row['Actual BRD Start Date']),
            'actual_brd_end_date': format_date(row['Actual BRD End Date (Gate 2)']),
            'planned_solution_design_start_date': format_date(row['Planned Solution Design Start Date (Gate 3)']),
            'planned_solution_design_end_date': format_date(row['Planned Solution Design End Date']),
            'actual_solution_design_start_date': format_date(row['Actual Solution Design Start Date']),
            'actual_solution_design_end_date': format_date(row['Actual Solution Design End Date (Gate 3)']),
            'external_vendors': external_vendors,
            'gate': f'Gate #{gate}',
            'display_date': display_date.strftime('%Y-%m-%d'),
            'num_days_offset': num_days_offset
        }
            
        loaded_doc = json.loads(json.dumps(doc))
        
        response=requests.post(elastic_url, json=loaded_doc, headers=headers)

def format_date(col):

    date_val = None

    if type(col) is not pd._libs.tslibs.nattype.NaTType:
        date_val = col.strftime('%Y-%m-%d')

    return date_val

def send_report_via_elastic_watcher():

    elastic_url = os.environ["ELASTIC_URL"]
    elastic_watcher_id = os.environ["ELASTIC_WATCHER_ID"]
    elastic_url=f'{elastic_url}/_watcher/watch/{elastic_watcher_id}/_execute'
    elastic_api_key = get_secret("ELASTIC_API_KEY")

    headers = {
        'Content-type': 'application/json', 
        'Authorization': f'ApiKey {elastic_api_key}'
    }

    doc={
        'ignore_condition': True,
        'action_modes': {
            'regen_reporting_data' : 'skip',
            'email_architects' : 'execute'
        },
        'record_execution': True
    }
        
    loaded_doc = json.loads(json.dumps(doc))

    response=requests.post(elastic_url, json=loaded_doc, headers=headers)

def get_secret(name):

    encrypted_secret = os.environ[name]
    # Decrypt code should run once and variables stored outside of the function
    # handler so that these are decrypted once per container
    decrypted_secret = boto3.client('kms').decrypt(
        CiphertextBlob=b64decode(encrypted_secret),
        EncryptionContext={'LambdaFunctionName': os.environ['AWS_LAMBDA_FUNCTION_NAME']}
    )['Plaintext'].decode('utf-8')

    return decrypted_secret
