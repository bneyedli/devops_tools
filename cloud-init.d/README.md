# cloud-init.d

Script to parse files prefixed numerically (00-,01-...) in a directory (preset to /etc/cloud-init.d/) and combine as a mime-multipart file, optionally base64 encoding and/or gziping.

Requires write-mime-multipart from cloud-image-utils on ubuntu or cloud-utils in the yum world

Example Use (base64 encode gzip and force overwrite with verbose output):
  
  cid -d /etc/cloud-init.d -o user-data -b -z -f -v


