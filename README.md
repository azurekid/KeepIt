[![Mr Robot fonts](https://see.fontimg.com/api/renderfont4/g123/eyJyIjoiZnMiLCJoIjoxNzEsInciOjI2MjUsImZzIjo2NSwiZmdjIjoiIzZGMTExMSIsImJnYyI6IiMwODAwMDAiLCJ0IjoxfQ/UiBvIGcgaSBlIHIgIEQgaSBqIGsgbSBhIG4/mrrobot.png)](https://www.fontspace.com/category/mr-robot)

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=comfortaa&color=016EEA&size=24&width=500&lines=Security+Researcher;Cloud+Security+Architect;Open-Source+Maintainer;Blogger)](https://git.io/typing-svg)

# 1Password - Microsoft Sentinel solution

## Introduction 

The 1Password Content Hub solution for Microsoft Sentinel is a community-developed project that enables organizations to ingest data from 1Password into their target SIEM/SOAR solution. Given that password managers inherently store highly sensitive information, monitoring and responding to any unexpected events is critically important.

By ingesting audit logs, sign-in events, and usage information into Microsoft Sentinel, this solution allows for the automation of incident responses, promptly notifying security analysts of potential issues.

The 1Password-Microsoft Sentinel solution includes a data connector, Azure workbook for visualizing password manager usage and features 18 unique analytics rules designed to identify and detect malicious behavior. 

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fazurekid%2F1Password-Sentinel%2Fmain%2FSolutions%2F1Password%2FData%2520Connectors%2F1Password%2Fazuredeploy_1Password_API_FunctionApp.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fazurekid%2F1Password-Sentinel%2Fmain%2FSolutions%2F1Password%2FData%2520Connectors%2F1Password%2Fdeployment%2FUiDefinition.json)

## Deploying the solution

For the deployment, a custom UI has been created to guide users through the setup process of the 1Password Solution for Microsoft Sentinel. On the first screen of the wizard, users are prompted to provide basic information for the deployment.  

Once the Resource Group is selected, the workspace field will automatically populate with the available workspaces.

![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/52746794-7c43-4781-b4e7-d2148852a7eb)
 
In the next screen of the installation wizard, details about the 1Password connection are requested, such as the 1Password API Key and the region.  

![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/5eed9949-4c4d-4178-a959-c2295b1f0f17)

After the setup is completed, a summary will be displayed showing the results of the deployed templates.

![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/e4e43d45-f37a-40b4-95e0-32f99d1bc234)

After some time, Microsoft Sentinel will start receiving data from the 1Password API, and the data connector will show as connected.

![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/ca6d5e08-5bb9-43e3-bb6f-110222474b53)

## Included resources

The 1Password solution contains the following components:
- Data connector using the 1Password API
- 18 analytics rules to identify and detect malicious behaviour
- A workbook to visualize activities within 1Password
- Parser (in development)
- Hunting rules (on backlog)

## Azure Workbook

Included in the solution is an Azure Workbook designed to offer insights into the usage of 1Password for Business.  
This workbook is divided into two sections: one for general information and another for user-specific data.

**All Data**  
The initial section of the 1Password workbook provides an overview of organizational usage.  
Within this section, graphical representations offer insights into frequently accessed locations, user activity, and 1Password version information.

![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/949d362b-70d8-4236-9544-2aea15a015f8)
![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/8ee38e88-e6a8-4367-b273-7052707e1f9a)

**User Data**  
This section presents insights into individual user activity within 1Password.  
It includea metrics such as the signin patterns application versions, authentication attempts, ip addresses, etc.

![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/ba502fac-7f3e-4eed-b9bb-b116aa0d5ee7)
![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/ed6550ca-4fc6-4daa-b564-77c3c3494967)

## Analytics Rules

The solution contains 18 Microsoft Sentinel analytics rules designed to detect and respond to potential security threats or suspicious activities within the organization's 1Password environment, enhancing the overall security posture and resilience against cyber threats.

![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/4aa767a2-f07f-432a-8835-c41e5867a6cb)

## Architecture

If we breakdown the 1Password solution for Microsoft Sentinel we can identity the following (inherited) resources
- Azure Key Vault
- Azure Function App (PowerShell based)
- System Assigned Managed Identity
- Storage Account
- Data Collection Rule (DCR)
- Date Collection Endpoint
- Custom Table for 1Password events

![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/039ca4c9-3a40-472b-a32e-875b32a97160)

## Solution description

At the core of this solution is the Azure FunctionApp, which serves as the link between Microsoft Sentinel and the 1Password for Business API. This FunctionApp leverages the [Log Ingestion API](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-ingestion-api-overview), utilizing a Data Collection Rule (DCR) instead of the older and deprecated [HTTP Data Collector API](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/data-collector-api?tabs=powershell) still used by most custom data connectors.

The Log Ingestion API offers several benefits compared to the older HTTP Data Collector API:

**Better Performance:**  
The Log Ingestion API has better performance and is more scalable. It can handle larger volumes which, makes it more suitable for high data ingestion needs.

**Data Collection Rules (DCR):**  
The use of Data Collection Rules (DCR) enables users to specify exactly what data should be collected, how it should be transformed, and where it should be sent.

**Improved Security:**  
The Log Ingestion API is more secure. It includes support for Workload Identities for authentication, which offers more secure and manageable access controls.

**Future proof:**  
As the Log Ingestion API is the latest and actively developed API, it is more likely to receive updates and support.

## Authentication and Secret management

The development of this solution follows a zero-trust approach and adheres to a least privileged model. All authentication to Azure resources is managed through system-assigned managed identities. In certain cases, secrets must be provided during deployment or generated on a fire-and-forget basis.

All secrets are securely stored in Azure Key Vault, which is accessible only by the system-assigned managed identity of the FunctionApp. Other sensitive information that would typically be found in the FunctionApp configuration is also stored and referenced within the Key Vault. Example This ensures that access is restricted, minimizing the risk of exposure to normal user accounts.

## Roles and Permissions

**Key Vault Access**  
The system-assigned managed identity (MI) of the FunctionApp has been granted the built-in `Key Vault Secrets User` role on the Azure Key Vault resource. This role provides the necessary permissions to read secrets in the Azure Key Vault, following to the least privileged access model.

**Data Collection Rule Access**  
The same Managed Identity is assigned the built-in `Monitoring Metrics Publisher` role on the data collection rule (DCR) resource. This role is used for authenticating requests to send logging data.

>NOTE: It may take up to 15 minutes for the role assignment to become active and for the DCR to start processing data.

**Deployment Permissions**  
During the deployment of the 1Password Solution for Microsoft Sentinel, role assignments are configured through the underlying ARM templates. Therefor the account or identity deploying the solution must have either Owner or User Access Administrator permissions in the target Resource Group in Azure.

## Data Flow

The next image illustrates the data flow for the integration between 1Password and Microsoft Sentinel.  

![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/8740e1b7-8017-4226-a7a0-50d47b31c1ef)

## Code Security

The Function Code of the 1Password Solution is scripted in PowerShell. To prevent tampering, code poisoning or misconfigurations, the function code is securely deployed as a zip deployment package. Modifying the code within the Azure Portal or in the storage account is not possible.

The code utilizes a custom PowerShell Module in the background to streamline the content in the run.ps1 file, which contains the fundamental code.

## Troubleshooting

- **No logging is received in the logging table**  
  After deploying the solution, it can take up to 30 minutes for the first log events to be processed. If no events are displayed after this period, check to ensure the Function App is running.
  
- **Only healthevents are shown**  
  By default, 1Password does not provide any health information through its APIs. The 1Password Solution for Sentinel runs every 5 minutes to check for new information. If no new information is available, only a timestamp will be written to the workspace.
  ![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/2339c3f8-3795-4088-8b8a-a50502757da0)

- **API Key Invalid**  
  After retrieving the API key from Azure Key Vault, a connection is established with the 1Password API to validate the key's validity.  To update the 1Password API key, you can either redeploy the 1Password solution for Microsoft Sentinel (recommended method) with the correct key or manually add a new API key in the designated field within the Azure Key Vault.
  
![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/261c274a-4232-4649-b721-d4314a0cfcb5)

- **API Key Invalid**  
If an invalid endpoint is provided during the solution setup, an API Key Invalid message may appear in the logs. This occurs when the claims in the OAuth token do not include the correct audience. To verify this, you can paste the OAuth token into jwt.ms. The API Endpoint can be manually updated in the Environment Variables section of the Function App.

![image](https://github.com/azurekid/1Password-Sentinel/assets/40334679/b3390dc3-7157-4f39-9662-6ec70b2249ea)

- **The log_source column is not found in the 1Password API documentation**  
  That is correct! the column `log_source` is created by the solution and shows from what API endpoint the data is received.
  This column is added for easy filtering on data source.
  
## Credits

> Special thanks to [Stefan Smit](https://www.linkedin.com/in/stefan-alexander-smit) who helped me out defining and building the analytics rules.  
> And thank you [Scott Lougheed](https://www.linkedin.com/in/scott-c-lougheed) for your addictive enthousiasm and believe in this community project.
