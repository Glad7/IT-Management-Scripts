import requests
import os
import Constants
import json
import time

#REQUIRED PARAMETERS SET IN ATERA FOR THIS TO WORK:
    #Meraki device must have the custom field 'Serial' set to the SERIAL NUMBER of the meraki device (acquired from the admin dashboard)

atera_service_key = Constants.ATERA_API_KEY
meraki_service_key = Constants.MERAKI_API_KEY
msteams_webhook_url = Constants.MSTeams_Webhook_Url
sleep_time = 600

meraki_path = 'https://api.meraki.com/api/v1'
atera_path = 'https://app.atera.com/api/v3'

#Returns Organization ID as string
def getOrgID():
    response = requests.get(meraki_path + '/organizations', 
                            headers = {
                                'Authorization': 'Bearer ' + meraki_service_key
                            })

    responseData = json.loads(response.content)
    return responseData[0]['id']

#Returns all the device names and corresponding status (offline, alerting, dormant, or online) as dict of {serial: status, ...}
def getDeviceStatus(org_id):
    #org_id = getOrgID()
    response = requests.get(meraki_path + '/organizations/' + org_id + '/devices/statuses', 
                            headers = {
                                'Authorization': 'Bearer ' + meraki_service_key
                            })

    responseData = json.loads(response.content)

    device_status = {}

    for i in range(0, len(responseData)):
        device_status[responseData[i]['serial']] = responseData[i]['status']
    #print(device_status)
    return device_status    
         
#Returns dict of {meraki device_id: atera deviceguid}
def getAteraMerakiDeviceIDs():

    meraki_devices = {}

    response = requests.get(atera_path + '/devices/snmpdevices', 
                                headers = {
                                    'X-API-KEY': atera_service_key
                                })

    responseData = json.loads(response.content)


    total_pages = responseData['totalPages']

    #assumes hostname for meraki devices in atera is 'snmp.meraki.com'
    for i in range(0, len(responseData['items'])):
        if responseData['items'][i]['Hostname'] == 'snmp.meraki.com':
            meraki_devices[responseData['items'][i]['DeviceID']] = responseData['items'][i]['DeviceGuid']

    for i in range(2, total_pages + 1):
        response = requests.get(atera_path + '/devices/snmpdevices', 
                                headers = {
                                    'X-API-KEY': atera_service_key
                                },
                                params= { 
                                    'page': i
                                })
        responseData = json.loads(response.content)

        for i in range(0, len(responseData['items'])):
            if responseData['items'][i]['Hostname'] == 'snmp.meraki.com':
                meraki_devices[responseData['items'][i]['DeviceID']] = responseData['items'][i]['DeviceGuid']
    
    #print(meraki_devices)
    return meraki_devices

#Returns dict of {Meraki Serial Number: deviceguid}. Used to link Meraki and Atera APIs with the serial number. 
#Need GUID for creating atera alerts in the future
def getAteraMerakiSerials(device_ids):
    meraki_guids = {}

    for id in device_ids:
        response = requests.get(atera_path + '/customvalues/snmpfield/' + str(id) + '/Serial', 
                                    headers = {
                                        'X-API-KEY': atera_service_key
                                    })
        responseData = json.loads(response.content)
        #print(responseData)
        meraki_guids[responseData[0]['ValueAsString']] = device_ids[id]
    return meraki_guids

#creates a new atera ticket for the device. Checks for an open ticket with same title before creating a new one
def createAteraTicket(serial):
    response = requests.get(meraki_path + '/devices/' + serial, 
                            headers = {
                                'Authorization': 'Bearer ' + meraki_service_key
                            })

    responseData = json.loads(response.content)
    device_name = responseData['name']

    flag = False

    response = requests.get(atera_path + '/tickets', headers = {
        'X-API-KEY': atera_service_key}, params = {
            'ticketStatus': 'Open',
        })
    
    responseData = json.loads(response.content)
    
    total_pages = responseData['totalPages']

    for i in range(0, len(responseData['items'])):
        if responseData['items'][i]['TicketTitle'] == "MERAKI DEVICE OFFLINE: " + device_name:
            flag = True

    if total_pages > 1:
        for i in range(2, total_pages + 1):
            response = requests.get(atera_path + '/devices/snmpdevices', 
                                    headers = {
                                        'X-API-KEY': atera_service_key
                                    },
                                    params= { 
                                        'page': i
                                    })
            responseData = json.loads(response.content)

            for i in range(0, len(responseData['items'])):
                if responseData['items'][i]['TicketTitle'] == "MERAKI DEVICE OFFLINE: " + device_name:
                    flag = True

    enduserID = 2
    match device_name:
        case "Device name in Meraki 1":
            enduserID = 56
        case "Device name in Meraki 2":
            enduserID = 379
        case "Device name in Meraki 3":
            enduserID = 415
        case "Device name in Meraki 4":
            enduserID = 78
        case "Device name in Meraki 5":
            enduserID = 68
        case "Device name in Meraki 6":
            enduserID = 83
        case "Device name in Meraki 7":
            enduserID = 401    
                 
    if flag == True:
        return -1
    else:
        response = requests.post(atera_path + '/tickets', headers = {
            'X-API-KEY': atera_service_key}, json = {
            "TicketTitle": "MERAKI DEVICE OFFLINE: " + device_name,
            "Description": "A Meraki Device is down.",
            "TicketPriority": "Critical",
            "TicketImpact": "Major",
            "TicketType": "Incident",
            "EndUserID": enduserID})
        responseData = json.loads(response.content)
        return responseData['ActionID']
    
def postMSTeams(serial):

    ticket_num = createAteraTicket(serial)

    #if a ticket already exists, doesn't bother posting to teams again
    if ticket_num == -1:
        return None

    response = requests.get(meraki_path + '/devices/' + serial, 
                            headers = {
                                'Authorization': 'Bearer ' + meraki_service_key
                            })

    responseData = json.loads(response.content)
    device_name = responseData['name']

    payload = {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        "themeColor": "0072C6",
        "summary": device_name + " is down",
        "sections": [
            {
                "activityTitle": "Meraki Device: " + device_name + " is down.",
                "activitySubtitle": "Ticket #: " + ticket_num
            }
        ],
        "potentialAction": [
            {
                "@type": "OpenUri",
                "name": "Open Ticket Page",
                "targets": [
                    {
                        "os": "default",
                        "uri": "https://app.atera.com/new/tickets/" + ticket_num
                    }
                ]
            }
        ]
    }

    response = requests.post(msteams_webhook_url, json=payload)
    #print(response)
        

def main():
    org_id = getOrgID()

    while True:
        status = getDeviceStatus(org_id)
        devices = status.keys()

        #you can add cases for other device statuses if you'd like
        for device in devices:
            match status[device]:
                case 'offline':
                    postMSTeams(device) 
        time.sleep(sleep_time)
                                      
main()                                      