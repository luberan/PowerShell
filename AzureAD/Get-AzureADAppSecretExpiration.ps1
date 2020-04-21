# Requires Azure AD PowerShell Module
#Prompts user to login using Azure Credentials

Connect-AzureAD
$results = @()
Get-AzureADApplication -All $true | %{  
                             $app = $_

                             $owner = Get-AzureADApplicationOwner -ObjectId $_.ObjectID -Top 1

                             $app.PasswordCredentials | 
                                %{ 
                                    $results += [PSCustomObject] @{
                                            CredentialType = "PasswordCredentials"
                                            DisplayName = $app.DisplayName; 
                                            AppId = $app.AppId;
                                            ExpiryDate = $_.EndDate;
                                            StartDate = $_.StartDate;
                                            KeyID = $_.KeyId;
                                            Type = 'NA';
                                            Usage = 'NA';
                                            Owners = $owner.UserPrincipalName;
                                        }
                                 } 
                                  
                             $app.KeyCredentials | 
                                %{ 
                                    $results += [PSCustomObject] @{
                                            CredentialType = "KeyCredentials"                                        
                                            DisplayName = $app.DisplayName; 
                                            ExpiryDate = $_.EndDate;
                                            StartDate = $_.StartDate;
                                            KeyID = $_.KeyId;
                                            Type = $_.Type;
                                            Usage = $_.Usage;
                                            Owners = $owner.UserPrincipalName;
                                        }
                                 }                            
                          }
$results | FT -AutoSize 

# Optionally export to a CSV file
#$results | Export-Csv -Path "AppsInventory.csv" -NoTypeInformation 
