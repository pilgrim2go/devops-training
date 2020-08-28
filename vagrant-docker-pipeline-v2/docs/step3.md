### Tasks 3 Deploy to Vagrant Prod


```
- hosts: prod
  become: yes
  vars:
      docker_apps_location: /usr/local/opt/

  tasks:

    - name: Ensure app folder exists.
      file: "path={{ docker_apps_location }} state=directory"      
      tags: docker_prod  

    - name: Copy docker daemon json  to server.
      copy: src=templates/docker-compose.prod.yml dest="{{ docker_apps_location }}"
      tags: docker_prod  
    - name: Run `docker-compose pull` to get latest app version
      command: /usr/local/bin/docker-compose -f docker-compose.prod.yml pull app
      args:
        chdir: "{{ docker_apps_location }}"        
      tags: docker_prod  


    - name: Run `docker-compose up` up
      command: /usr/local/bin/docker-compose -f docker-compose.prod.yml up -d
      args:
        chdir: "{{ docker_apps_location }}"        
      tags: docker_prod  

    - name: Wait for port 4002 to become open on the host, don't start checking for 10 seconds
      wait_for:
        port: 4002
        delay: 10        
      tags: docker_prod  

    - name: Using curl to connect to a host port 4002 . Ordinarily this would throw a warning.
      shell: curl  localhost:4002
      args:
        warn: no
      register: output
      tags: docker_prod  

    - debug:
        var: output.stdout
      tags: docker_prod  

```      