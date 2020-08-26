#### Deploy to Prod
`vagrant ssh prod`

`sudo vim docker-compose.prod.yml`

add following content

```
version: "3"

services: 
  app:
    container_name: app
    image: registry:5000/app:1
    restart: always
    environment: 
      - PORT=4002
    ports: 
      - "4002:4002"
    links:
      - mongo
  mongo:
    container_name: mongo
    image : mongo
    volumes: 
      - ./data:/data/db
    ports: 
      - "27017:27017
```      


Note that we're refering an image built on Dev

`image: registry:5000/app:1`

#### Add registry
sudo bash -c  "echo 192.168.2.3 registry >> /etc/hosts"
sudo vim /etc/docker/daemon.json
udo systemctl restart docker

#### Up and Running

`sudo docker-compose -f docker-compose.prod.yml up -d`

Now goes to http://192.168.2.4:4002

it should work