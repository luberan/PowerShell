$application = New-Object -ComObject word.application
$application.Visible = $false
$document = $application.documents.open("C:\Users\luberan\Desktop\Test C3.docx")
$binding = "System.Reflection.BindingFlags" -as [type]
$customProperties = $document.CustomDocumentProperties
foreach($Property in $customProperties)
{
 $pn = [System.__ComObject].InvokeMember("name",$binding::GetProperty,$null,$property,$null)
 if ($pn -eq "DocumentClasification") {
   [System.__ComObject].InvokeMember("value",$binding::GetProperty,$null,$property,$null)
   }
}
$application.quit()
