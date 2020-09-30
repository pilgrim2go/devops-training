## Full Source References
https://github.com/rgl/jenkins-vagrant

#
Make sure the package index cache is up-to-date before installing anything.

`apt-get update`




#
### create a self-signed certificate.
`domain=$(hostname --fqdn)`

```
pushd /etc/ssl/private
openssl genrsa \
    -out $domain-keypair.pem \
    2048 \
    2>/dev/null
chmod 400 $domain-keypair.pem
openssl req -new \
    -sha256 \
    -subj "/CN=$domain" \
    -key $domain-keypair.pem \
    -out $domain-csr.pem
openssl x509 -req -sha256 \
    -signkey $domain-keypair.pem \
    -extensions a \
    -extfile <(echo "[a]
        subjectAltName=DNS:$domain
        extendedKeyUsage=serverAuth
        ") \
    -days 365 \
    -in  $domain-csr.pem \
    -out $domain-crt.pem
popd
```


### Install nginx as a proxy to Jenkins.

`apt-get install -y --no-install-recommends nginx`

```
cat >/etc/nginx/sites-available/jenkins <<EOF
ssl_session_cache shared:SSL:4m;
ssl_session_timeout 6h;
#ssl_stapling on;
#ssl_stapling_verify on;
server {
    listen 80;
    server_name _;
    return 301 https://$domain\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $domain;
    client_max_body_size 50m;

    ssl_certificate /etc/ssl/private/$domain-crt.pem;
    ssl_certificate_key /etc/ssl/private/$domain-keypair.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    # see https://github.com/cloudflare/sslconfig/blob/master/conf
    # see https://blog.cloudflare.com/it-takes-two-to-chacha-poly/
    # see https://blog.cloudflare.com/do-the-chacha-better-mobile-performance-with-cryptography/
    # NB even though we have CHACHA20 here, the OpenSSL library that ships with Ubuntu 16.04 does not have it. so this is a nop. no problema.
    ssl_ciphers EECDH+CHACHA20:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!aNULL:!MD5;
    add_header Strict-Transport-Security "max-age=31536000; includeSubdomains";

    access_log /var/log/nginx/$domain-access.log;
    error_log /var/log/nginx/$domain-error.log;

    # uncomment the following to debug errors and rewrites.
    #error_log /var/log/nginx/$domain-error.log debug;
    #rewrite_log on;

    location ~ "(/\\.|/\\w+-INF|\\.class\$)" {
        return 404;
    }

    location ~ "^/static/[0-9a-f]{8}/plugin/(.+/.+)" {
        alias /var/lib/jenkins/plugins/\$1;
    }

    location ~ "^/static/[0-9a-f]{8}/(.+)" {
        rewrite "^/static/[0-9a-f]{8}/(.+)" /\$1 last;
    }

    location /userContent/ {
        root /var/lib/jenkins;
    }

    location / {
        root /var/cache/jenkins/war;
        try_files \$uri @jenkins;
    }

    location @jenkins {
        proxy_pass http://127.0.0.1:8080;
        proxy_redirect default;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

```
```
rm /etc/nginx/sites-enabled/default
ln -fs ../sites-available/jenkins /etc/nginx/sites-enabled/jenkins
systemctl restart nginx
```

#### Check nginx status

```
systemctl status nginx
● nginx.service - A high performance web server and a reverse proxy server
   Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2020-09-30 07:05:15 UTC; 14s ago
     Docs: man:nginx(8)
  Process: 3275 ExecStop=/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid (code=exited, status=0/SUCCESS)
  Process: 3379 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
  Process: 3369 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
 Main PID: 3380 (nginx)
    Tasks: 3 (limit: 2362)
   CGroup: /system.slice/nginx.service
           ├─3380 nginx: master process /usr/sbin/nginx -g daemon on; master_process on;
           ├─3382 nginx: worker process
           └─3383 nginx: worker process

Sep 30 07:05:15 jenkins10 systemd[1]: Starting A high performance web server and a reverse proxy server...
Sep 30 07:05:15 jenkins10 systemd[1]: Started A high performance web server and a reverse proxy server.

```


#### Install dependencies.

```
apt-get install -y openjdk-8-jre-headless
apt-get install -y gnupg
apt-get install -y xmlstarlet
```



Fix "java.lang.NoClassDefFoundError: Could not initialize class org.jfree.chart.JFreeChart"
error while rendering the xUnit Test Result Trend chart on the job page.

```
sed -i -E 's,^(\s*assistive_technologies\s*=.*),#\1,' /etc/java-8-openjdk/accessibility.properties 
```



### Install Jenkins.

```
wget -qO- https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add -
echo 'deb http://pkg.jenkins.io/debian-stable binary/' >/etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y --no-install-recommends jenkins
```

```
pushd /var/lib/jenkins
#### wait for initialization to finish.
bash -c 'while [ "$(xmlstarlet sel -t -v /hudson/installStateName config.xml 2>/dev/null)" != "NEW" ]; do sleep 1; done'

systemctl stop jenkins


chmod 751 /var/cache/jenkins
mv config.xml{,.orig}
# remove the xml 1.1 declaration because xmlstarlet does not support it... and xml 1.1 is not really needed.
tail -n +2 config.xml.orig >config.xml
```

##### disable security.

```
# see https://wiki.jenkins-ci.org/display/JENKINS/Disable+security
xmlstarlet edit --inplace -u '/hudson/useSecurity' -v 'false' config.xml
xmlstarlet edit --inplace -d '/hudson/authorizationStrategy' config.xml
xmlstarlet edit --inplace -d '/hudson/securityRealm' config.xml
# disable the install wizard.
xmlstarlet edit --inplace -u '/hudson/installStateName' -v 'RUNNING' config.xml
# modify the slave workspace directory name to be just "w" as a way to minimize
# path-too-long errors on windows slaves.
# NB unfortunately this setting applies to all slaves.
# NB in a pipeline job you can also use the customWorkspace option.
# see windows/provision-jenkins-slaves.ps1.
# see https://issues.jenkins-ci.org/browse/JENKINS-12667
# see https://wiki.jenkins.io/display/JENKINS/Features+controlled+by+system+properties
# see https://github.com/jenkinsci/jenkins/blob/jenkins-2.138.2/core/src/main/java/hudson/model/Slave.java#L722
sed -i -E 's,^(JAVA_ARGS="-.+),\1\nJAVA_ARGS="$JAVA_ARGS -Dhudson.model.Slave.workspaceRoot=w",' /etc/default/jenkins
# bind to localhost.
sed -i -E 's,^(JENKINS_ARGS="-.+),\1\nJENKINS_ARGS="$JENKINS_ARGS --httpListenAddress=127.0.0.1",' /etc/default/jenkins
```

####  configure access log.
```
# NB this is useful for testing whether static files are really being handled by nginx.
sed -i -E 's,^(JENKINS_ARGS="-.+),\1\nJENKINS_ARGS="$JENKINS_ARGS --accessLoggerClassName=winstone.accesslog.SimpleAccessLogger --simpleAccessLogger.format=combined --simpleAccessLogger.file=/var/log/jenkins/access.log",' /etc/default/jenkins
sed -i -E 's,^(/var/log/jenkins/)jenkins.log,\1*.log,' /etc/logrotate.d/jenkins
# show the configuration changes.
diff -u config.xml{.orig,} || true
popd
```

`systemctl start jenkins`

### Configure Jenkins


```
source /vagrant/jenkins-cli.sh
function jcli {
    $JCLI -noKeyAuth "$@"
}

# wait for the cli endpoint to be available.
jcliwait
```


```
# customize.
# see http://javadoc.jenkins-ci.org/jenkins/model/Jenkins.html
jgroovy = <<'EOF'
import hudson.model.Node.Mode
import jenkins.model.Jenkins

// disable usage statistics.
Jenkins.instance.noUsageStatistics = true

// do not run jobs on the master.
Jenkins.instance.numExecutors = 0
Jenkins.instance.mode = Mode.EXCLUSIVE

Jenkins.instance.save()
EOF
```


```
# set the jenkins url and administrator email.
# see http://javadoc.jenkins-ci.org/jenkins/model/JenkinsLocationConfiguration.html
jgroovy = <<EOF
import jenkins.model.JenkinsLocationConfiguration

c = JenkinsLocationConfiguration.get()
c.url = 'https://$domain'
c.adminAddress = 'Jenkins <jenkins@example.com>'
c.save()
EOF

```

```
# install and configure git.
apt-get install -y git-core
su jenkins -c bash <<'EOF'
set -eux
git config --global user.email 'jenkins@example.com'
git config --global user.name 'Jenkins'
git config --global push.default simple
git config --global core.autocrlf false
git config --global http.sslverify "false"

EOF

```


```
# install plugins.
# NB installing plugins is quite flaky, mainly because Jenkins (as-of 2.19.2)
#    does not retry their downloads. this will workaround it by (re)installing
#    until it works.
# see http://javadoc.jenkins-ci.org/jenkins/model/Jenkins.html
# see http://javadoc.jenkins-ci.org/hudson/PluginManager.html
# see http://javadoc.jenkins.io/hudson/model/UpdateCenter.html
# see http://javadoc.jenkins.io/hudson/model/UpdateSite.Plugin.html
jgroovy = <<'EOF'
import jenkins.model.Jenkins
Jenkins.instance.updateCenter.updateAllSites()
EOF
function install-plugins {
jgroovy = <<'EOF'
import jenkins.model.Jenkins

updateCenter = Jenkins.instance.updateCenter
pluginManager = Jenkins.instance.pluginManager

installed = [] as Set

def install(id) {
  plugin = updateCenter.getPlugin(id)

  plugin.dependencies.each {
    install(it.key)
  }

  if (!pluginManager.getPlugin(id) && !installed.contains(id)) {
    println("installing plugin ${id}...")
    pluginManager.install([id], false).each { it.get() }
    installed.add(id)
  }
}

[
    'cloudbees-folder',
    'email-ext',
    'gitlab-plugin',
    'git',
    'powershell',
    'xcode-plugin',
    'xunit',
    'conditional-buildstep',
    'workflow-aggregator', // aka Pipeline; see https://plugins.jenkins.io/workflow-aggregator
    'ws-cleanup', // aka Workspace Cleanup; see https://plugins.jenkins.io/ws-cleanup
].each {
  install(it)
}
EOF
}
while [[ -n "$(install-plugins)" ]]; do
    systemctl restart jenkins
    jcliwait
done
```


```
# use the local SMTP MailHog server.
jgroovy = <<'EOF'
import jenkins.model.Jenkins

c = Jenkins.instance.getDescriptor('hudson.tasks.Mailer')
c.smtpHost = 'localhost'
c.smtpPort = '1025'
c.save()
EOF
```

```
# configure the default pipeline durability setting as performance-optimized.
# see https://jenkins.io/doc/book/pipeline/scaling-pipeline/
# see https://javadoc.jenkins.io/plugin/workflow-api/org/jenkinsci/plugins/workflow/flow/GlobalDefaultFlowDurabilityLevel.DescriptorImpl.html
jgroovy = <<'EOF'
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.flow.GlobalDefaultFlowDurabilityLevel

d = Jenkins.instance.getDescriptor('org.jenkinsci.plugins.workflow.flow.GlobalDefaultFlowDurabilityLevel')
d.durabilityHint = 'PERFORMANCE_OPTIMIZED'
d.save()
EOF
```


#### configure security.

Generate the SSH key-pair that jenkins master uses to communicates with the slaves.

`su jenkins -c 'ssh-keygen -q -t rsa -N "" -f ~/.ssh/id_rsa'`



##### Enable simple security.

also create the vagrant user account. jcli will use this account from now on.

```
# see http://javadoc.jenkins-ci.org/hudson/security/HudsonPrivateSecurityRealm.html
# see http://javadoc.jenkins-ci.org/hudson/model/User.html
jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import hudson.tasks.Mailer

Jenkins.instance.securityRealm = new HudsonPrivateSecurityRealm(false)

u = Jenkins.instance.securityRealm.createAccount('vagrant', 'vagrant')
u.fullName = 'Vagrant'
u.addProperty(new Mailer.UserProperty('vagrant@example.com'))
u.save()

Jenkins.instance.authorizationStrategy = new FullControlOnceLoggedInAuthorizationStrategy(
  allowAnonymousRead: true)

Jenkins.instance.save()
EOF
```

######Create the vagrant user api token.

```
# see http://javadoc.jenkins-ci.org/hudson/model/User.html
# see http://javadoc.jenkins-ci.org/jenkins/security/ApiTokenProperty.html
# see https://jenkins.io/doc/book/managing/cli/
function jcli {
    $JCLI -http -auth vagrant:vagrant "$@"
}
jgroovy = >~/.jenkins-cli <<'EOF'
import hudson.model.User
import jenkins.security.ApiTokenProperty

u = User.current()
p = u.getProperty(ApiTokenProperty)
t = p.tokenStore.generateNewToken('vagrant')
u.save()
println sprintf("%s:%s", u.id, t.plainValue)
EOF
chmod 400 ~/.jenkins-cli
```

Redefine jcli to use the vagrant api token.
```

source /vagrant/jenkins-cli.sh

# show which user is actually being used in jcli. this should show "vagrant".
# see http://javadoc.jenkins-ci.org/hudson/model/User.html
jcli who-am-i
jgroovy = <<'EOF'
import hudson.model.User

u = User.current()
println sprintf("User id: %s", u.id)
println sprintf("User Full Name: %s", u.fullName)
u.allProperties.each { println sprintf("User property: %s", it) }; null
EOF

```

##### Create example accounts (when using jenkins authentication).


```
# see http://javadoc.jenkins-ci.org/hudson/model/User.html
# see http://javadoc.jenkins-ci.org/hudson/security/HudsonPrivateSecurityRealm.html
# see https://github.com/jenkinsci/mailer-plugin/blob/master/src/main/java/hudson/tasks/Mailer.java
if [ "$config_authentication" = 'jenkins' ]; then
jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.tasks.Mailer

[
    [id: "alice.doe",   fullName: "Alice Doe"],
    [id: "bob.doe",     fullName: "Bob Doe"  ],
    [id: "carol.doe",   fullName: "Carol Doe"],
    [id: "dave.doe",    fullName: "Dave Doe" ],
    [id: "eve.doe",     fullName: "Eve Doe"  ],
    [id: "frank.doe",   fullName: "Frank Doe"],
    [id: "grace.doe",   fullName: "Grace Doe"],
    [id: "henry.doe",   fullName: "Henry Doe"],
].each {
    u = Jenkins.instance.securityRealm.createAccount(it.id, "password")
    u.fullName = it.fullName
    u.addProperty(new Mailer.UserProperty(it.id+"@example.com"))
    u.save()
}
EOF
fi

```

Create artifacts that need to be shared with the other nodes.

```

mkdir -p /vagrant/tmp
pushd /vagrant/tmp
cp /var/lib/jenkins/.ssh/id_rsa.pub $domain-ssh-rsa.pub
cp /etc/ssl/private/$domain-crt.pem .
openssl x509 -outform der -in $domain-crt.pem -out $domain-crt.der
popd
```


##### Add the ubuntu slave node.

```
# see http://javadoc.jenkins-ci.org/jenkins/model/Jenkins.html
# see http://javadoc.jenkins-ci.org/jenkins/model/Nodes.html
# see http://javadoc.jenkins-ci.org/hudson/slaves/DumbSlave.html
# see http://javadoc.jenkins-ci.org/hudson/model/Computer.html

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.slaves.DumbSlave
import hudson.slaves.CommandLauncher

node = new DumbSlave(
    "ubuntu",
    "/var/jenkins",
    new CommandLauncher("ssh ubuntu.jenkins.example.com /var/jenkins/bin/jenkins-slave"))
node.numExecutors = 3
node.labelString = "ubuntu 18.04 linux amd64"
node.mode = 'EXCLUSIVE'
Jenkins.instance.nodesObject.addNode(node)
Jenkins.instance.nodesObject.save()
EOF
```
