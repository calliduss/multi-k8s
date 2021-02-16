# k8s

This project focused on deployment side of Kubernetes in Google cloud. Web application is the same as in [this repo](https://github.com/calliduss/multi-docker) 

Below is overall architecture of the web application deployed in Google Cloud:
![Architecture](https://github.com/calliduss/multi-k8s/blob/master/figures/k8s_arch.PNG)

Project structure (only deployment side):
```
 .travis.yml
 deploy.sh
 service-account.json.enc

├───client
│   │   Dockerfile
│   │   Dockerfile.dev
│   │
│   └───nginx
│          default.conf
│
├───k8s
│       client-cluster-ip-service.yml
│       client-deployment.yml
│       database-persistent-volume-claim.yml
│       ingress-service.yml
│       postgres-cluster-ip-service.yml
│       postgres-deployment.yml
│       redis-cluster-ip-service.yml
│       redis-deployment.yml
│       server-cluster-ip-service.yml
│       server-deployment.yml
│       worker-deployment.yml
│
├───server
│      Dockerfile
│	   Dockerfile.dev
│      
└───worker
       Dockerfile
       Dockerfile.dev
```

## Description

k8s directory consists config files that described deployments, services (ClusterIp) and PVC. 

##### NodePort vs ClusterIP services

In the world of Kubernetes we use a service object type any time we want to set up some networking for an object such as single pod or a group of pods that is managed by a deployment.
**ClusterIP** is not accessible from outside world. It provides access to an object (commonly a set of pods) to everything else inside of a cluster. It's not allowed for traffic to come in from the outside world
Our **ClusterIP** will only be accessible through the Ingress service

In `deployment-postgres.yml` specified only one replica:
```
spec:
  replicas: 1
```

This is because we can face with the situation where two different DBs (in different containers) access the same value. They (DBs) should be aware of each other.
If we let Postgres save all its data inside the file system maintained by the container we are going to lose it as soon as this pod or container crashes.
[Datastorage inside a container](https://github.com/calliduss/multi-k8s/blob/master/figures/datastorage_inside_container.PNG)

To solve this problem we are using volumes

##### Volumes
- a *Volume* in Kubernetes world: An object that allows a container to store data at the pod level;
- a *Volume* in container terminology: Some type of mechanism that allows a container to access a filesystem outside itself

When create a volume in k8s we are creating a data storage pocket that exist for a specific pod. The value can be accessed by any container in the pod. 
Kubernetes volume data will survive container restart, but not pod killing.

- Persistent volume - if a container or pod that contains container failed then data will not be lost because it's stored outside pod
- Persistent volume claim (PVC) - not a storage, it can't store anything, not an actual volume. 
It's a request for storage, which is met by binding the PVC to a persistent volume (PV). 
A cluster inspects the claim to find the bound volume and mounts that volume for the Pod.


### Production setup of kubernetes in Google Cloud:

First of all link Github repo to Travis-CI: http://travis-ci.com/

##### Creating a Google Cloud project
1. Open https://console.cloud.google.com/
2. Create a project: 
- Open project menu using dropdown on the top left side -> click on [New project]
3. Give a project any name, for instance: `multi-k8s`


##### Linking a Billing Account to the project
In order to do all the Kubernetes stuff it's necessary to associate your credit/debit card with your Google account.
So as to enable billing open navigation menu on the top left side -> select Billing -> link a billing account.

Depending on a region you can face with the situation where you cannot select `individual billing type` as payment profile and will be forced to use `business profile`: https://stackoverflow.com/questions/43318162/google-cloud-platform-individual-billing
So, in this case create a Business billing account

##### Kubernetes setup in Google cloud
1. Open the navigation menu on the top left side
2. In "Compute" section select "Kubernetes engine"
3. Choose type of cluster and enable Kubernetes Engine: *Regional Kubernetes Clusters Anthos*
4. Create cluster
- Go through wizard to create a new cluster:
  - **Name:** multi-cluster (naming is totally up to you)
  - **Location type:** Zonal
  - **Zone:** choose closest to your geographic location
  - **Master version:** leave as default setting 

##### .travis.yml
- Install Google Cloud SDK CLI;
- Configure the SDK with Google cloud auth info;
- Login to Docker CLI;
- Build the 'test' version of multi-client (only one image while the application contains three of them);
- Run tests (remember, this application is dummy example and tests are empty and will always pass);
- If successful run a script to deploy the newest images;
- Build all our images (latest and git commit version ($SHA)), tag each one, push each to Docker hub;
- Apply all configs in the 'k8s' folder;
- Imperatively set latest images on each deployment;

##### How to get credentials in Google Cloud SDK?
- Create a service account;
- Download service account credentials as a `.json` file;
- Download and install Travis CLI;
- Encrypt and upload the `.json` file to Travis account;
- In `.travis.yml` add code to encrypt the `.json` file and load into GCloud

Step by step instruction:
1. Navigate to Google Cloud Dashboard 
2. Open menu ... 
3. IAM $ Admin 
4. Service accounts 
5. Create service account 
6. Give any name, for instance: `travis-deployer`
7. Select a role: Kubernetes Engine -> Kubernetes Engine Admin. 
After creation open created service account and add a new key -> Create new private key -> choose type `.json`, name it `service-account.json` to make it easier to work with

**DO NOT EXPOSE THIS FILE TO OUTSIDE WORLD! Because it has some sensitive information.**

##### Install Travis CLI inside a container
To encrypt the `service-account.json` file it's necessary to install Travis CLI on a local machine. 
That is required to install ruby as well. Nevertheless, there is a tricky workaround - we can encrypt the file in docker container with pre - installed Ruby: 

1. Navigate to project location in your terminal window
2. Execute: `docker run -it -v ${pwd}:/app ruby:2.4 sh` to download and run container with pre - installed Ruby
- where `/app` is a folder inside a container
- `-v` allows us to use volumes to work with files outside of container FS
- `sh` will start Shell command line inside a container.
 
 **ps:** use `$(pwd)` for linux

3.`cd app` -> `gem install travis` -> run `travis` to make sure everything installed correctly -> it's going to ask you if want to install Shell completion, we don't need it, so press `N`

The Travis login now requires a Github Token. 
Please follow these instructions to generate a Personal Token for Travis to use here: https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token

`travis login --github-token YOUR_PERSONAL_TOKEN --com`

Encryption: 

Preparations: 
- copy `service-account.json` file into the 'volumed' directory (root directory of the project on a local machine), so we can use it in the container
- ensure that you are in `/app` folder in the container (`pwd`)
- ensure that `service-account.json` is available for the container (`ls` in `/app` folder)
- tie encrypted file to repo: `travis encrypt-file service-account.json -r YOUR_DOCKER_ID/multi-k8s --com`

in the result you will see a warning to add a command to `.travis.yml` in `before_install` section:

`openssl  acssslfddlldf....`

copy and paste to `.travis.yml`

then add **service-account.json.enc** to the git repo

**DELETE THE ORIGINAL .JSON!**

##### Why do we use $SHA? 
Any time we build an image If we do not specify a tag the implicit understanding is that it automatically applied the `latest` tag to it.
When we run `kubectl set image deployments/server-deployments server=YOUR_DOCKER_ID/multi-server` that deployment looks at latest image.
Then deployment looks at that image name and recognizes that image with `latest` tag is already running, so there is no need to make any changes.
To prevent this behaviour it's recommended to tag an image with the unique version number - SHA. It's a way of tracking of deployments. 
SHA is a unique identifier token that's always going to be different, and it identifies the state of our codebase at very particular point in time. 
Perfect to use as Version identifiers for our images.

##### Creating a secret in Google Cloud
1. Navigate to Google cloud dashboard
2. Choose your project (for instance: `multi-k8s` or the name you gave)
3. Activate cloud shell (right up corner)
4. We need to set **project ID**, **compute zone** and credentials as we did it in `.travis.yml`
for instance:
```
gcloud config set project silken-hulling-304812
gcloud config set compute/zone eu-north1-a
gcloud container clusters get-credentials multi-cluster
```
- where `skillfull-berm-214822` is projectId generated by Google
- `eu-north1-a` is compute zone that is specified when we create a project in Google cloud

test connection:
`kubectl get pods`

*No resources have found* which is expected

5.` kubectl create secret generic pgpassword --from-literal PGPASSWORD=mypgpassword123` 

6.Refresh the page on a dashboard -> configuration. 
  - Expected result: secret has been created.

##### How to install Helm v3
Helm is a program that we can use to administering the third party software inside of a kubernetes cluster
https://helm.sh/docs/intro/install/#from-script

To install it we need to open shell again
```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

Install Ingress-Nginx:
https://kubernetes.github.io/ingress-nginx/deploy/#using-helm
In your Google Cloud Console run the following:
```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install my-release ingress-nginx/ingress-nginx
```

After installation refresh dashboard -> workload or services -> you will see ingress and load balancer
									 
### How to clean up Google cloud cluster?

You just need to delete the project in the cloud and billing will be stopped