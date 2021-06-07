<<-EOF
  #!/bin/bash
  mkdir /var/www/html/dev
    echo "<h1>Software deployment is all of the activities that make a software system</h1>" > /var/www/html/dev/index.html
    service httpd start
    chkconfig httpd on
EOF
