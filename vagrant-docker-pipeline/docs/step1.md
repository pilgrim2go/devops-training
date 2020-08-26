## Pre-requisites
  1. Download this project and put it wherever you want.
  2. Open Terminal, cd to this directory (containing the `Vagrantfile` and this README file).
  3. Run `ansible-galaxy install -r requirements.yml` to install required Ansible roles.
  4. Type in `vagrant up`, and let Vagrant do its magic.

#### Check

  make sure all boxes are properly configured ( have docker setup)

eg, 

```
vagrant ssh dev
sudo docker ps

```


#### Setup Git in Dev box

`  vagrant up --provision dev`


#### Build Sample Projects

Go to Dev box

`vagrant ssh dev`

Clone sample project

`git clone https://github.com/ganeshmani/node-multistage-docker`

Build image

`sudo docker-compose build`

Testing

`sudo docker-compose up -d`

Run
`curl localhost:4002`
or Accesss `http://192.168.2.2:4002` 

Should returns
`Home Route`



##### Trouble shooting
```
ERROR: Couldn't connect to Docker daemon at http+docker://localhost - is it running?

If it's at a non-standard location, specify the URL with the DOCKER_HOST environment variable.

```
Make sure you have rights to run Docker