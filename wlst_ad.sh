#!/bin/bash

# Common Variables
export app_home="/app" # Directory where domain was installed
export wlstf="wlst-secure.sh" # wlst script name
export bootf=$(find ${app_home} -name boot.properties) # boot.properties full path
export wls_senha=$(awk -F "=" '/password/{print $NF}' ${bootf}) # weblogic encrypt admin password
export tmpfile="tmp.py" # Temp Python file run WLST
export certfile="ad.pem" # AD Certificate
export adencpass="IUFcVdzJZzY0PrPC0KAA" # Base64 Password
export adpass=$(echo ${adencpass} | base64 --decode) # Decode AD Connection Password
export userencf=".wlsuser.secure" # Weblogic Credentials - User
export passencf=".wlspass.secure" # Weblogic Credentials - Password
export wlsenvfile=$(find ${app_home} -name setWLSEnv.sh | grep -iv templates) # setWLSEnv.sh Full Path
export domains_home=$(find ${app_home} -name "domains") # Domain_Home Path
export mydomain=$(ls ${domains_home}) # Domain Name
export config_file="${domains_home}/${mydomain}/config/config.xml" # config.xaml full path
export intf="$(nmcli -f name con -s | awk 'NR>1' | sed 's/ *$//')" # Interface connection Name
export myconsola=$(nmcli con show "$intf" |awk '/ipv4.addresses/{print $NF}' | cut -d "/" -f1) # Ip address interface
export nm_host="$(hostname -f)" # Full FQDN - Hosname.domain
export nm_port=5556 # NodeManager Port
export wls_port=7002 # Weblogic Port (SSL)
export user_config_file=$(find ${app_home} -name ".nmusercfg.secure") # NodeManager Credentials - User
export user_key_file=$(find ${app_home} -name ".nmuserkey.secure")    # NodeManager Credentials - Password
export keypath="$(find ${app_home} -name keystores)/common/" # Keystore Path
export keypass=$(awk -F "[><]" '/custom-trust-key-store-pass-phrase-encrypted/{print $3}' ${config_file} | awk 'NR==1&&/AES256/') # TrustStore Encrypted Password
export JAVA_OPTIONS="-Dweblogic.security.CustomTrustKeyStoreFileName=${keypath}/trust.jks -Dweblogic.security.CustomTrustKeyStorePassPhrase=${keypass} \
  -Dweblogic.security.TrustKeyStore=CustomTrust -Dweblogic.security.CustomTrustKeyStoreType=JKS -Dweblogic.security.allowCryptoJDefaultPRNG=true \
  -Dweblogic.security.allowCryptoJDefaultJCEVerification=true -Doracle.jdbc.fanEnabled=false" # JAVA OPTIONS - use into secure wlst script

# Decrypt.py
# Mount wlst decrypt scripts

func_DECRYPT(){

        senha=$1 # Receive of function
        # Create python file into bash script
        cat << EOF > ${tmpfile} 
import sys
from weblogic.security.internal import *
from weblogic.security.internal.encryption import *
encryptionService = SerializedSystemIni.getEncryptionService("${domains_home}/${mydomain}")
cs = ClearOrEncryptedService(encryptionService)
pwd = "${senha}"
decpwd = cs.decrypt(pwd)
print (decpwd)
EOF

}

# Functions to execute wlst scripts
# RUN WLST to Decrypt weblogic and Trust Passwords

func_VARWLST(){

        cleanpass=$(${wlstf} 2>/dev/null ${tmpfile} | tail -n 1) # execute wlst decrypt and store weblogic password
        if [ -f ${tmpfile} ];then rm -f ${tmpfile}; fi # Remove tmp python file, if exists.
        echo ${cleanpass} # Print weblogic password to use with blank pass variables
}

# Run WLST to invoke other python files
func_RUNWLST(){

        ${wlstf} ${tmpfile} # Invoke python file
        if [ -f ${tmpfile} ];then rm -f ${tmpfile}; fi # Remove tmp python file, if exists.
}

# Create secure wlst file

echo ". ${wlsenvfile}" >> ${wlstf}
echo "JAVA_OPTIONS=${JAVA_OPTIONS}" >> ${wlstf}
echo "java #.{JAVA_OPTIONS} weblogic.WLST #.1 #.2" >> ${wlstf}
sed -i 's/#./\$/g' ${wlstf} # Chage #. to $ for mount correct variable name
chmod +x ${wlstf} # Set secure wlst file to execute

# Run wlst functions to decrypt weblogic and trust passwords

func_DECRYPT "${wls_senha}"
blankwlspass=$(func_VARWLST) # Store weblogic blank password

# Create script to encrypt password file
cat << EOF > ${tmpfile}
connect(username='weblogic',password='${blankwlspass}',url='t3s://${myconsola}:${wls_port}'),storeUserConfig(userConfigFile='${userencf}',userKeyFile='${passencf}',nm='false')
EOF
func_RUNWLST

func_DECRYPT "${keypass}"
blankkeypass=$(func_VARWLST) # Store truststore blank password

# Create AD certificate
# Insert certificate value below lines.

cat << EOF > ${certfile}
-----BEGIN CERTIFICATE-----
aW4tc2F1ZGUucHQwTwYJKwYBBAGCNxkCBEIwQKA+BgorBgEEAYI3GQIBoDAELlMt
kjiojiovnjgvuiojp+IPOUIeihNJHDIOJSOIJoojjddeTiCnztEo/JTq4swOIcXJ
aW4tc2F1ZGUucHQwTwYJKwYBBAGCNxkCBEIwQKA+BgorBgEEAYI3GQIBoDAELlMt
HhcNMjMwMTIzMTcxNjI5WhcNMjQwMTIzMTcxNjI5WjAAMIIBIjANBgkqhkiG9w0B
kjiojiovnjgvuiojp+IPOUIeihNJHDIOJSOIJoojjddeTiCnztEo/JTq4swOIcXJ
aW4tc2F1ZGUucHQwTwYJKwYBBAGCNxkCBEIwQKA+BgorBgEEAYI3GQIBoDAELlMt
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
AgIwDgYDVR0PAQH/BAQDAgWgMDUGCSsGAQQBgjcVCgQoMCYwCgYIKwYBBQUHAwIw
AQEFAAOCAQ8AMIIBCgKCAQEAzaojfAYuZi1A9Vakb2EUTiCnztEo/JTq4swOIcXJ
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
dGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVjdENsYXNzPWNSTERpc3Ry
aWJ1dGlvblBvaW50MIHHBggrBgEFBQcBAQSBujCBtzCBtAYIKwYBBQUHMAKGgads
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
AQEFAAOCAQ8AMIIBCgKCAQEAzaojfAYuZi1A9Vakb2EUTiCnztEo/JTq4swOIcXJ
mfkjvipokapasxkçlkjpwGhvcml0eTAjBgNVHREBAf8EGTAXksiokjdjdoihsdji
aW4tc2F1ZGUucHQwTwYJKwYBBAGCNxkCBEIwQKA+BgorBgEEAYI3GQIBoDAELlMt
-----END CERTIFICATE-----
EOF

# Create python file to set AD provider, set control flag, insert certificate AD to trust, restart weblogic admin, and set policys.

# AD.py

# Varibles use with AD python script

provider_name="ActiveDirectory" # Define provider name
provider_control="SUFFICIENT" # Define Flag to provider: SUFFICENT, REQUIRED or OPTIONAL 
base_dn="DC=my-org,DC=my-place,DC=pt" # Define AD basedn
group_dn="OU=MyGroup,OU=Myvalues,${base_dn}" Define group tree
user_dn="OU=MyOrg,OU=Mydepartmant,OU=Mygroup,OU=Mygroup,${base_dn}" # Define user DN
ldap_port=636 # Define AD secure port
ldap_host="myldap.my-server.pt" # Define AD host
members=(groupa groupb groupc) # Define AD groups to set memberof and policy map.

# Create AD python script to use with wlst

cat << EOF > ${tmpfile}
import os # To execute keytool into python script

# Define keytoll command
keycommand = 'keytool -import -keystore ${keypath}trust.jks -file ${certfile} -alias ${provider_name} -storepass ${blankkeypass} -noprompt'

# Define weblogic and nodemanager connections function
def wls_connection()
  connect(userConfigFile='${userencf}',userKeyFile='${passencf}',url='t3s://${myconsola}:${wls_port}')
def nm_connection()
  nmConnect(userConfigFile='${user_config_file}',userKeyFile='${user_key_file}',domainName='${mydomain}',port='${nm_port}',host='${nm_host}')
  
# Configure AD provider
wls_connection()
edit()
startEdit()
cd('/SecurityConfiguration/${mydomain}/Realms/myrealm')
cmo.createAuthenticationProvider('${provider_name}', 'weblogic.security.providers.authentication.ActiveDirectoryAuthenticator')
cd('/SecurityConfiguration/${mydomain}/Realms/myrealm/AuthenticationProviders/${provider_name}')
cmo.setControlFlag('${provider_control}')
cmo.setGroupBaseDN('${group_dn},${base_dn}')
cmo.setPort('${ldap_port}')
cmo.setUserBaseDN('${user_dn}${base_dn}')
cmo.setSSLEnabled(true)
cmo.setResultsTimeLimit(10)
cmo.setConnectionRetryLimit(3)
cmo.setConnectTimeout(5)
set('Credential','${adpass}')
cmo.setHost('${ldap_host}')
cmo.setUserFromNameFilter('(&(sAMAccountName=%u)(objectclass=user)(|(memberof=cn=${members[0]},${group_dn},${base_dn})(memberof=cn=${members[1],${group_dn},${base_dn})(memberof=cn=architects,${group_dn},${base_dn})))')
cmo.setGroupFromNameFilter('(&(cn=%g)(objectclass=group)(|(cn=${members[0]})(cn=${members[1])(cn=${members[2])))')
cmo.setUserNameAttribute('sAMAccountName')
cmo.setPrincipal('osi-apps')
cd('/SecurityConfiguration/${mydomain}/Realms/myrealm/AuthenticationProviders/DefaultAuthenticator')
cmo.setControlFlag('${provider_control}')

# Configure Default Authenticator Flag
cd('/SecurityConfiguration/${mydomain}/Realms/myrealm')
set('AuthenticationProviders',jarray.array([ObjectName('Security:Name=myrealmTrust Service Identity Asserter'), ObjectName('Security:Name=myrealmDefaultAuthenticator'), ObjectName('Security:Name=myrealmActiveDirectory'), ObjectName('Security:Name=myrealmDefaultIdentityAsserter')], ObjectName))

# Finish provider settings
save()
activate()
disconnect()

# Insert AD Certificate into TrustStore
os.system(keycommand)

# Restart Admin Server with nodemanager
nm_connection()
nmKill('AdminServer')
nmStart('AdminServer')
disconnect()

# Edit global policy
wls_connection()
edit()
startEdit(-1,-1,'false')
serverConfig()
cd('/SecurityConfiguration/${mydomain}/Realms/myrealm/RoleMappers/XACMLRoleMapper')
cmo.setRoleExpression('','Admin','Grp(${members[2])|Grp(${members[0]})|Grp(Administrators)')    
cmo.setRoleExpression('','Operator','Grp(${members[1])|Grp(Operators)')                         
edit()
undo(defaultAnswer='y', unactivatedChanges='true')
stopEdit('y')
disconnect()

EOF

${wlstf} ${tmpfile} # Run wlst to execute AD script
