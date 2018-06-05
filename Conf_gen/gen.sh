#!/bin/bash
for ((i=3;i<=10000;i++)); do  
curl -v -u admin:Qwerty123 -X POST -H 'Content-Type: application/json' -H 'Accept: application/json'  -d'{"type":"page","title":'$i',"space":{"key":"TES"},"body":{"storage":{"value":"<p>This is a new page </p>","representation":"storage"}}}' conf2-vc60-pkt:8090/rest/api/content/?os_authType=basic; 
done