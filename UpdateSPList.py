from shareplum import Site
from requests_ntlm import HttpNtlmAuth
import csv

cred = HttpNtlmAuth('domain\\vennem', 'password')
site = Site('https://sharepoint.domain.local/admin', verify_ssl=False, auth= cred)
sp_list = site.List('SharePoint Business Owners and POCs')

with open('C:\\Users\\vennem\\Desktop\\ciso.csv') as csvfile:
    readcsv = csv.reader(csvfile,delimiter=',')
    next(readcsv)
    for row in readcsv:
        if row[5]=="Readable by all of domain":
            Access = "All domain"
        else:
            Access = "Team"
        newitemdata = [{'Site Title': row[1]},
                       {'Primary Point of Contact': row[2]},
                       {'Secondary POC': row[3]},
                       {'Primary Owners Group': row[4]},
                       {'Relative URL': row[0][29:]},
                       {'Division and Office': 'row[6]'},
                       {'Q1 FY2019 Audit': 'Complete'},
                       {'Access Restricted to': Access}]
        sp_list.UpdateListItems(data=newitemdata, kind='New')


