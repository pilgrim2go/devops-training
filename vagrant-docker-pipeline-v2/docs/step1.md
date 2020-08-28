
### Prepare

Add inventories in `inventories/vagrant/inventory`

```
[dev]
192.168.2.2 ansible_ssh_user=vagrant ansible_ssh_private_key_file=/Users/nowhereman/.vagrant.d/insecure_private_key
[registry]
192.168.2.3 ansible_ssh_user=vagrant ansible_ssh_private_key_file=/Users/nowhereman/.vagrant.d/insecure_private_key
[prod]
192.168.2.4 ansible_ssh_user=vagrant ansible_ssh_private_key_file=/Users/nowhereman/.vagrant.d/insecure_private_key
[all]
[dev]
[registry]
[prod]
```

add `ansible.cfg`

```
[defaults]
host_key_checking = False
#roles_path = ./roles
nocows = 1
retry_files_enabled = False

[ssh_connection]
pipelining = True

```

#### Task 1

Review https://github.com/pilgrim2go/devops-training/blob/master/vagrant-docker-pipeline/docs/step1.md

Now we will convert all manual steps to 1 step using Ansible Automation.

##### Task 1.1 Clone sample project


```
    - name: Ensure app folder exists.
      file: "path={{ docker_apps_location }} state=directory"      
    - name: Checkout source
      git:
        repo: 'https://github.com/pilgrim2go/node-multistage-docker'
        dest: "{{ docker_apps_location }}"
```        


##### What we learnt

Using git module https://docs.ansible.com/ansible/latest/modules/git_module.html


##### Task 1.2 Build image

```
    - name: Run `docker-compose up` build
      command: /usr/local/bin/docker-compose build app
      args:
        chdir: "{{ docker_apps_location }}"        
```

see Ansible `command` https://docs.ansible.com/ansible/latest/modules/command_module.html

##### Task 1.4 debug command output

```
    - name: Run `docker-compose up` build
      command: /usr/local/bin/docker-compose build app
      args:
        chdir: "{{ docker_apps_location }}"        
      register: output
    - debug:
        var: output
```

See `register` https://docs.ansible.com/ansible/latest/reference_appendices/common_return_values.html

and  `debug` https://docs.ansible.com/ansible/latest/modules/debug_module.html


#### Task 1.5 Run docker-compose

```
    - name: Run `docker-compose up` up
      command: /usr/local/bin/docker-compose up -d
      args:
        chdir: "{{ docker_apps_location }}"        
```

#### Task 1.6 Testing

```
    - name: Using curl to connect to a host port 4002 . Ordinarily this would throw a warning.
      shell: curl  localhost:4002
      args:
        warn: no
      register: output
    - debug:
        var: output
```

#### Task 1.6 Testing CI

Update source code

Rerun ansible
`ansible-playbook -i inventories/vagrant/inventory provision.yml --limit dev --tags docker_build_run`

Check output

```
TASK [debug] ********************************************************************
ok: [192.168.2.2] => {
    "output.stdout": "Home Route. Chào các bạn NC"
}
```



#### Task 1.7 Tag Image


##### Get Git Version

```
    - name: get git version
      shell: git rev-parse --short=4 HEAD
      args:
        chdir: "{{ docker_apps_location }}"      
      tags: docker_tag  

      register: git_version

```


##### Tag Image

```
    - name: tag image 
      shell: docker tag pilgrim2go/node-multistage-docker:latest pilgrim2go/node-multistage-docker:"{{ git_version.stdout }}"
      tags: docker_tag  
```