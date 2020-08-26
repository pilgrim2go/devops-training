#### A development life cycle

Go to dev

`vagrant ssh dev`

Edit source code

`sudo vim src/index.js`

Update content. For example

`res.send("Home Route. This is version 2");`


#### Build app
`sudo docker-compose build app`

##### Versioning

`sudo docker tag node-multistage-docker_app registry:5000/app:2`

##### Push again

`sudo docker push registry:5000/app:2`


##### Update Prod with new version

`vagrant ssh prod`

Update docker-compose.yml to use v2 image

```
services: 
  app:
    container_name: app
    image: registry:5000/app:2
```

##### Up and Running

 docker-compose -f docker-compose.prod.yml up -d

