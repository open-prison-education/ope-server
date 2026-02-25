#!/usr/bin/python
import os, sys
import socket
import shutil
import uuid
import subprocess

# Is this script called with the auto param? Suppress prompts
auto = False

if len(sys.argv) > 1:
    if sys.argv[1] == "auto":
        auto = True

# Rebuild the docker-compose file

## Write this to the docker-compose.yml file
dc_out = """##### Open Prison Education - Docker Environment #####
# NOTE - This file gets rebuilt, make changes to docker-compose-include.yml file
#           in individual container directories and run rebuild.sh 
#
# Start docker containers by running this command from the main folder:
#        docker-compose up -d
#
# Stop containers by running this command from the main folder:
#        docker-compose down
#
# Alternatively, use from the main folder:
#        up.sh   - to start containers
#        down.sh - to stop containers
#
# START OF docker-compose.yml
version: "2"

<VOLUMES>

#networks:
#  host_network:
#    external:
#      name: host
#  default:
#    external:
#      name: bridge
#  default:
#    driver: bridge
#    name: ope
#      driver_opts:
#         com.docker.network.bridge.default_bridge: "true"
#         com.docker.network.bridge.enable_icc: "true"
#         com.docker.network.bridge.enable_ip_masquerade: "true"
#         com.docker.network.bridge.host_binding_ipv4: "0.0.0.0"
#         com.docker.network.bridge.name: "ope"
#         com.docker.network.driver.mtu: "1500"
#     internal: true


services:

"""

# A list of values to substitute in the docker-compose.yml or .env.template file
replacement_values = {
    "<DOMAIN>": "ed",
    "<IP>": "",
    "<VOLUMES>": "",
    "<NETWORK_MODE>": "bridge",
    "<CANVAS_SECRET>": "<NEW_UUID>",
    "<IT_PW>": "changeme",
    "<OFFICE_PW>": "changeme",
    "<LMS_ACCOUNT_NAME>": "Open Prison Education",
    "<TIME_ZONE>": "Pacific Time (US & Canada)",
    "<CANVAS_LOGIN_PROMPT>": "Student ID (default is s + DOC number - s113412)",
    "<CANVAS_DEFAULT_DOMAIN>": "canvas.<DOMAIN>",
    "<SMC_DEFAULT_DOMAIN>": "smc.<DOMAIN>",
    "<IS_ONLINE>": "0",
    "<DNS_EXTRAS>": "",
    "<ACME_AUTH_CODE>": "ZZZZ",
    "<CANVAS_ENC_SECRET>": "<NEW_UUID_32>",
    "<CANVAS_SIGN_SECRET>": "<NEW_UUID_32>",
    "<CANVAS_RCE_DEFAULT_DOMAIN>": "rce.<DOMAIN>",
    "<CANVAS_MATHMAN_DEFAULT_DOMAIN>": "mathman.<DOMAIN>",
    "<NTP_SERVERS>": "time.windows.com",
    "<ALERT_EMAIL>": "alert@correctionsed.com",
    "<CERT_NAME>": "default",
}

# A list of volumes that need to be specified in the volumes section
volume_list = []


def getComposeFolder():
    pwd = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return pwd


# Find the local/public ip of the machine
def getIP():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    IP = ""
    try:
        s.connect(("10.255.255.255", 0))
        IP = s.getsockname()[0]
    except:
        IP = subprocess.check_output(["hostname", "-i"])
        IP = IP.strip()
    finally:
        s.close()
    return IP

def getSavedSetting(setting_name="", default_val=None):
    # Locate the base folder
    pwd = getComposeFolder()
    # <IP> would be .IP file
    setting_file = os.path.join(pwd, "." + setting_name.replace("<", "").replace(">", ""))
    ret = default_val
    try:
        with open(setting_file, "r") as f:
            ret = f.read().strip()
        if ret == "":
            ret = default_val
    except:
        print("No setting file found: " + setting_name)
    # print("Got setting " + setting_file + ":" + ret)
    return ret

def saveSetting(setting_name="", value=""):
    # Locate the base folder
    pwd = getComposeFolder()
    setting_file = os.path.join(pwd, "." + setting_name.replace("<", "").replace(">", ""))
    with open(setting_file, "w") as f:  
        f.write(value)

def processFolder(cwd=""):
    global volume_list

    ret = ""
    if (os.path.isdir(cwd) != True):
        return ret

    enabled = os.path.join(cwd, ".enabled")
    if (os.path.isfile(enabled) != True):
        #print("Not enabled, skipping " + cwd)
        return ret
    
    print("Processing Folder " + cwd)
    
    dc_import = os.path.join(cwd, "docker-compose-include.yml")
    if (os.path.isfile(dc_import) != True):
        print("        Skipping - No docker-compose-include.yml file found")

    try:
        with open(dc_import, "r") as f:
            ret = f.read()
    except:
        print("         Error reading " + dc_import)
        ret = ""
    
    # Make sure to add some line feeds to the end in case the this has tabs on
    # the current line which messes up the yml format
    ret += "\n\n"
    
    # See if we need to import volumes
    vol_import = os.path.join(cwd, "volumes-include.yml")
    if (os.path.isfile(vol_import) != True):
        #print("\t\tNo volumes file.")
        return ret
    
    print("\nProcessing volume file: " + vol_import)
    
    try:
        with open(vol_import, "r") as f:
            lines = f.readlines()
            for line in lines:
                line = line.strip()
                # Strip off comments
                i = line.find("#")
                if (i > -1):
                    line = line[0:i]
                line = line.strip()
                if (line != ""):
                    print("\t===> Volume Found: " + line)
                    volume_list.append(line)

    except:
        print("\t\tError reading " + vol_import)
    
    return ret


# Load up each value
for k in replacement_values:
    replacement_values[k] = getSavedSetting(k, replacement_values[k])
    # print("Val " + str(replacement_values[k]))

# Make sure canvas secret is a new uuid if it is blank
if replacement_values["<CANVAS_SECRET>"] == "":
    replacement_values["<CANVAS_SECRET>"] = "<NEW_UUID>"

# Make sure enc secrets are 32byte strings
if replacement_values["<CANVAS_ENC_SECRET>"] == "":
    replacement_values["<CANVAS_ENC_SECRET>"] = "<NEW_UUID_32>"

if replacement_values["<CANVAS_SIGN_SECRET>"] == "":
    replacement_values["<CANVAS_SIGN_SECRET>"] = "<NEW_UUID_32>"

# Make sure IP is set to current IP if blank
if replacement_values["<IP>"] == "":
    replacement_values["<IP>"] = getIP()

# Make sure <NEW_UUID> values are replaced with an ID
for k in replacement_values:
    if replacement_values[k] == "<NEW_UUID>":
        replacement_values[k] = str(str(uuid.uuid4()) + "000").strip()

# Make sure <NEW_UUID_32> values are replaced w a 32 byte value
for k in replacement_values:
    if replacement_values[k] == "<NEW_UUID_32>":
        replacement_values[k] = str(str(uuid.uuid4()) + "000").strip()[:32]

t_ip = replacement_values["<IP>"]
t_domain = replacement_values["<DOMAIN>"]

# Make sure each value has the <DOMAIN> and <IP> values replaced in them
for k in replacement_values:
    replacement_values[k] = replacement_values[k].replace("<IP>", t_ip)
    replacement_values[k] = replacement_values[k].replace("<DOMAIN>", t_domain)


# Save current values
for k in replacement_values:
    saveSetting(k, replacement_values[k])
    # print("Saved " + k + ":" + str(replacement_values[k]))


# Grab current folder, then move back one
pwd = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if not os.path.isdir(pwd):
    print("Unable to find docker build files at: " + pwd)
    sys.exit()
else:
    print("Rebuilding docker compose...")
#print(" " + pwd)
#sys.exit()

# Make sure the .env file exists
env_file = os.path.join(pwd, ".env")
env_template_file = os.path.join(pwd, ".env.template")
# always rebuild env if auto is true
# NOTE: Always rebuild env file!!!
if (os.path.isfile(env_file) != True or auto is True or True):
    # Try to copy the .env.template file
    if (os.path.isfile(os.path.join(pwd, ".env.template")) == True):
        print("\n            New environment file - change values in .env file\n")
        shutil.copy(env_template_file, env_file)
    else:
        print("No env file found! Create a .env file to store your settings")

if (os.path.isfile(env_file) == True):
    # Replace template tags with values from the replacement_values array
    
    # Read the current file in
    env_f = open(env_file, "r")
    lines = env_f.read()
    env_f.close()

    # Replace the values
    for key in replacement_values:
        lines = lines.replace(key, replacement_values[key])
    
    # Save the finished env file
    env_f = open(env_file, "w")
    env_f.write(lines)
    env_f.close()

# Loop through the folders and find containers with .enabled files.
for folder in os.listdir(pwd):
    dc_out += processFolder(os.path.join(pwd, folder))

# Use the volume_list to create a value for replacement
if (len(volume_list) > 0):
    v = "volumes:\n"
    for vol in volume_list:
        v += "    " + vol + "\n"
    replacement_values["<VOLUMES>"] = v

# Replace instances of template tags with values from the replacement_values array
for key in replacement_values:
    dc_out = dc_out.replace(key, replacement_values[key])

# Clear the current docker-compose.yml file and write the new file
docker_compose = open(os.path.join(pwd,"docker-compose.yml"), "w")
docker_compose.write(dc_out)
docker_compose.close()    
print("\n\nRebuild Compose Complete.")
#print("\n\n    Run commands from docker_build_files folder: {0}\n        To Build (Online Only):     docker-compose build\n        To start:             docker-compose up -d\n        To Stop:             docker-compose down".format(pwd))



# ------------------------------------------------------------------
sys.exit(0)
