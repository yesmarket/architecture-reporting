import os
import boto3
from base64 import b64decode
import requests
from bs4 import BeautifulSoup
import pandas as pd
from datetime import datetime
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
        
    aggregate_id=datetime.now().strftime('%Y%m%d%H%M')

    rollover_elastic_index()

    space_id = os.environ["CONFLUENCE_SPACE_ID"]

    arc_ids = get_confluence_ids(space_id, "arc_item")
    arc_props = get_props(space_id, "arc_item", arc_ids, "ARC")
    arc_df = convert_to_dataframe(arc_props, ['category','title','Type','Date','Primary author','Status','Project sponsor / Org unit / Domain'])
    arc_df['Project sponsor / Org unit / Domain'] = arc_df['Project sponsor / Org unit / Domain'].str.replace('^\s*$', 'Undefined', regex=True)
    write_docs_to_elastic(arc_df, aggregate_id)

    da_ids = get_confluence_ids(space_id, "da_item")
    da_props = get_props(space_id, "da_item", da_ids, "DA")
    da_df = convert_to_dataframe(da_props, ['category','title','Type','Date','Primary author','Status'])
    write_docs_to_elastic(da_df, aggregate_id)

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

def get_props(space, label, ids, category):

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
            page_properties['category']=category
            page_properties['title']=data["detailLines"][0]['title']

            for i in range(0, len(renderedHeadings)):
                heading=BeautifulSoup(renderedHeadings[i], "html.parser")
                detail=BeautifulSoup(details[i], "html.parser")
                page_properties[heading.get_text().strip()]=detail.get_text().strip()

            props.append(page_properties)

    return props

def convert_to_dataframe(props, columns):
    
    df = pd.DataFrame(props, columns=columns)

    df = df[df.Date != 'TBD']
    df['Date'] = pd.to_datetime(df['Date'].str.strip())
    df = df[df['Date'].dt.year >= 2023]
    df.sort_values(by='Date',inplace = True)
    df["Primary author"] = df["Primary author"].str.replace(" \(Unlicensed\)", "").str.replace(".", " ")

    return df

def write_docs_to_elastic(df, aggregate_id):
    
    elastic_url = os.environ["ELASTIC_URL"]
    elastic_datastream = os.environ["ELASTIC_DATASTREAM"]
    elastic_url=f'{elastic_url}/{elastic_datastream}/_doc'
    elastic_api_key = get_secret("ELASTIC_API_KEY")

    headers = {
        'Content-type': 'application/json', 
        'Authorization': f'ApiKey {elastic_api_key}'
    }
            
    for i, row in df.iterrows():

        org_unit = None
        if row['category'] == "ARC":
            org_unit = row['Project sponsor / Org unit / Domain']
        
        doc={
            'category': row['category'],
            'date': row['Date'].strftime('%Y-%m-%d'),
            'title': row['title'],
            'type': row['Type'],
            'author': row['Primary author'],
            'org_unit': org_unit,
            'status': row['Status'],
            'aggregate_id': aggregate_id
        }
            
        loaded_doc = json.loads(json.dumps(doc))
        
        response=requests.post(elastic_url, json=loaded_doc, headers=headers)

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
