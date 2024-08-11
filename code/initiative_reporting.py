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
    df['Planned BRD Completed Date'] = pd.to_datetime(df['Planned BRD Completed Date'].str.strip(), errors='coerce')
    df['Actual BRD Start Date'] = pd.to_datetime(df['Actual BRD Start Date'].str.strip(), errors='coerce')
    df['Actual BRD Completed Date'] = pd.to_datetime(df['Actual BRD Completed Date'].str.strip(), errors='coerce')

    df['BRD Signoff Date (Gate 2)'] = pd.to_datetime(df['BRD Signoff Date (Gate 2)'].str.strip(), errors='coerce')

    df['Planned Solution Design Start Date'] = pd.to_datetime(df['Planned Solution Design Start Date'].str.strip(), errors='coerce')
    df['Planned Solution Design Completed Date'] = pd.to_datetime(df['Planned Solution Design Completed Date'].str.strip(), errors='coerce')
    df['Actual Solution Design Start Date'] = pd.to_datetime(df['Actual Solution Design Start Date'].str.strip(), errors='coerce')
    df['Actual Solution Design Completed Date'] = pd.to_datetime(df['Actual Solution Design Completed Date'].str.strip(), errors='coerce')

    df['Solution Design Signoff Date (Gate 3)'] = pd.to_datetime(df['Solution Design Signoff Date (Gate 3)'].str.strip(), errors='coerce')

    df['Planned Implementation Start Date'] = pd.to_datetime(df['Planned Implementation Start Date'].str.strip(), errors='coerce')
    df['Planned Implementation Completion Date'] = pd.to_datetime(df['Planned Implementation Completion Date'].str.strip(), errors='coerce')
    df['Actual Implementation Start Date'] = pd.to_datetime(df['Actual Implementation Start Date'].str.strip(), errors='coerce')
    df['Actual Implementation Completion Date'] = pd.to_datetime(df['Actual Implementation Completion Date'].str.strip(), errors='coerce')

    df['Planned Ready for Test Start Date'] = pd.to_datetime(df['Planned Ready for Test Start Date'].str.strip(), errors='coerce')
    df['Planned Ready for Test Completed Date'] = pd.to_datetime(df['Planned Ready for Test Completed Date'].str.strip(), errors='coerce')
    df['Actual Ready for Test Start Date'] = pd.to_datetime(df['Actual Ready for Test Start Date'].str.strip(), errors='coerce')
    df['Actual Ready for Test Completed Date (Gate 4)'] = pd.to_datetime(df['Actual Ready for Test Completed Date (Gate 4)'].str.strip(), errors='coerce')

    df['Planned CAB Signoff Date'] = pd.to_datetime(df['Planned CAB Signoff Date'].str.strip(), errors='coerce')
    df['CAB Signoff Date (Gate 5)'] = pd.to_datetime(df['CAB Signoff Date (Gate 5)'].str.strip(), errors='coerce')

    df['Planned Go Live Date'] = pd.to_datetime(df['Planned Go Live Date'].str.strip(), errors='coerce')
    df['Actual Go Live Date'] = pd.to_datetime(df['Actual Go Live Date'].str.strip(), errors='coerce')

    df['Budget'] = df['Budget'].replace('[\$,]', '', regex=True)
    df['Percentage Complete (for current status)'] = pd.to_numeric(df['Percentage Complete (for current status)'].replace('[\%,]', '', regex=True), errors='coerce')*0.01

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
        delivery_squads = [x.strip() for x in row['Delivery Squad(s)'].split(',')]
        business_analysts = [x.strip() for x in row['Business Analyst(s)'].split(',')]
        solution_architects_tech_leads = [x.strip() for x in row['Solution Architect(s) / Tech Lead(s)'].split(',')]
        level_of_design = [x.strip() for x in row['Level of Design'].split(',')]
        products_impacted = [x.strip() for x in row['Product(s) Impacted'].split(',')]
        external_vendors = [x.strip() for x in row['External Vendor(s)'].split(',')]
        external_vendors_engaged = True if row['External Vendor(s) Engaged'].lower() == 'yes' else False
        
        display_date = row['Date Created']
        if type(row['Actual BRD Start Date']) is not pd._libs.tslibs.nattype.NaTType and row['Actual BRD Start Date'].date() <= date.today():
            display_date = row['Actual BRD Start Date']
        elif type(row['Planned BRD Start Date']) is not pd._libs.tslibs.nattype.NaTType and row['Planned BRD Start Date'].date() <= date.today():
            display_date = row['Planned BRD Start Date']
            
        doc={
            'name': row['title'],
            'executive_sponsors': executive_sponsors,
            'executive_sponsors_str': row['Executive Sponsor(s)'],
            'business_owners': business_owners,
            'business_owners_str': row['Business Owner(s)'],
            'delivery_managers': delivery_managers,
            'delivery_managers_str': row['Delivery Manager(s)'],
            'delivery_squads': delivery_squads,
            'delivery_squads_str': row['Delivery Squad(s)'],
            'business_analysts': business_analysts,
            'business_analysts_str': row['Business Analyst(s)'],
            'solution_architects_tech_leads': solution_architects_tech_leads,
            'solution_architects_tech_leads_str': row['Solution Architect(s) / Tech Lead(s)'],
            'level_of_design': level_of_design,
            'products_impacted': products_impacted,
            'products_impacted_str': row['Product(s) Impacted'],
            'budget': row['Budget'],
            'delivery_approach': row['Delivery Approach'],
            'date_created': getFormattedDate(row['Date Created']),
            'link_to_brd': row['Link to BRD'],
            'link_to_initiative_funding_paper': row['Link to Initiative Funding Paper'],
            'link_to_jira_board': row['Link to Jira Board'],
            'link_to_solution_design': row['Link to Solution Design'],
            'status': row['Status'],
            'current_status_percent_complete': None if pd.isna(row['Percentage Complete (for current status)']) else row['Percentage Complete (for current status)'],
            'planned_brd_start_date': getFormattedDate(row['Planned BRD Start Date']),
            'planned_brd_end_date': getFormattedDate(row['Planned BRD Completed Date']),
            'actual_brd_start_date': getFormattedDate(row['Actual BRD Start Date']),
            'actual_brd_end_date': getFormattedDate(row['Actual BRD Completed Date']),
            'brd_signoff_date': getFormattedDate(row['BRD Signoff Date (Gate 2)']),
            'planned_solution_design_start_date': getFormattedDate(row['Planned Solution Design Start Date']),
            'planned_solution_design_end_date': getFormattedDate(row['Planned Solution Design Completed Date']),
            'actual_solution_design_start_date': getFormattedDate(row['Actual Solution Design Start Date']),
            'actual_solution_design_end_date': getFormattedDate(row['Actual Solution Design Completed Date']),
            'solution_design_signoff_date': getFormattedDate(row['Solution Design Signoff Date (Gate 3)']),
            'planned_implementation_start_date': getFormattedDate(row['Planned Implementation Start Date']),
            'planned_implementation_end_date': getFormattedDate(row['Planned Implementation Completion Date']),
            'actual_implementation_start_date': getFormattedDate(row['Actual Implementation Start Date']),
            'actual_implementation_end_date': getFormattedDate(row['Actual Implementation Completion Date']),
            'planned_ready_for_test_start_date': getFormattedDate(row['Planned Ready for Test Start Date']),
            'planned_ready_for_test_end_date': getFormattedDate(row['Actual Ready for Test Start Date']),
            'actual_ready_for_test_start_date': getFormattedDate(row['Planned Ready for Test Completed Date']),
            'actual_ready_for_test_end_date': getFormattedDate(row['Actual Ready for Test Completed Date (Gate 4)']),
            'planned_cab_date': getFormattedDate(row['Planned CAB Signoff Date']),
            'actual_cab_date': getFormattedDate(row['CAB Signoff Date (Gate 5)']),
            'planned_go_live_date': getFormattedDate(row['Planned Go Live Date']),
            'actual_go_live_date': getFormattedDate(row['Actual Go Live Date']),
            'external_vendors': external_vendors,
            'external_vendors_engaged': external_vendors_engaged,
            'statement_of_work_design_status': row['Statement of Work - Design'],
            'statement_of_work_implementation_status': row['Statement of Work - Implementation'],
            'display_date': display_date.strftime('%Y-%m-%d')
        }

        loaded_doc = json.loads(json.dumps(doc))
        
        response=requests.post(elastic_url, json=loaded_doc, headers=headers)

def getFormattedDate(col):

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

    if os.environ["ENVIRONMENT_VARIABLE_ENCRYPTION"].lower() != "true":

        return os.environ[name]
    
    else:

        encrypted_secret = os.environ[name]
        # Decrypt code should run once and variables stored outside of the function
        # handler so that these are decrypted once per container
        decrypted_secret = boto3.client('kms').decrypt(
            CiphertextBlob=b64decode(encrypted_secret),
            EncryptionContext={'LambdaFunctionName': os.environ['AWS_LAMBDA_FUNCTION_NAME']}
        )['Plaintext'].decode('utf-8')

        return decrypted_secret
