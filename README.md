# web_setup.sh
It will install Moodle with basic components

# Post installation tasks
1) Secure Database by strong password
2) SSL for web server (we recommend https://letsencrypt.org/)
3) Plan for HA/Scalable deployment architecture
4) Install Unoconv and LibreOffice (converting documents into pdf)
5) Configure caching appropriately for both sessions and application
6) Configure ClamAV (anti virus)
7) Configure Solr (global search functionality)
8) Configure external email server (we recommend AWS SES)
9) [optional] Move data directory to S3 (https://moodle.org/plugins/tool_objectfs)

# References
1) https://github.com/aws-samples/aws-refarch-moodle
2) https://github.com/Azure/Moodle
