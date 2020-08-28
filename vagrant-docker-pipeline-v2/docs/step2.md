### Task 2 - Setup Registry


#### Task 2.1 Registry Host

```
    - name: Add Ansible inventory mappings to /etc/hosts
      become: true
      blockinfile:
        path: /etc/hosts
        block: |
          {% for host in groups['registry'] %}
          {{ host }} registry
          {% endfor %}    
      tags: infra_ready

```      


#### Allow Docker to push image to insecure registry

```
    - name: Copy docker daemon json  to server.
      copy: src=templates/docker_daemon.json dest=/etc/docker/daemon.json
      tags: registry_ready

    - name: Restart service docker, in all cases
      service:
        name: docker
        state: restarted
      tags: registry_ready
```      

#### Start Docker registry


```
	- hosts: registry
	  become: yes
	  tasks:

	    - name: Start registry
	      shell: docker run -d -p 5000:5000 --restart=always --name registry registry:2

```  
