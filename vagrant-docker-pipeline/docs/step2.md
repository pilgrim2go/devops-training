#### Deploy Registry

https://docs.docker.com/registry/deploying/

`docker run -d -p 5000:5000 --restart=always --name registry registry:2`
#### Set registry

Add Registry DNS to `/etc/hosts` so that Docker can reach

`sudo bash -c  "echo 192.168.2.3 registry >> /etc/hosts"`

##### Push to Registry

```
sudo docker tag node-multistage-docker_app registry:5000/app:1
sudo docker push registry:5000/app:1
```

*Notes*:

If we've got following error. Make sure we're running Registry under https or we need to tell Docker to make it insecure
```
The push refers to repository [registry:5000/app]
Get https://192.168.2.3:5000/v2/: http: server gave HTTP response to HTTPS client

```

#### Allow Docker to push image to insecure registry

`sudo vim /etc/docker/daemon.json`

add 

```
    {
    "insecure-registries" : ["registry:5000"]
    }
```

Remember to restart Docker

`sudo systemctl restart docker`

see more
https://docs.docker.com/registry/insecure/
