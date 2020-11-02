# Regular command examples

List running containers (add -a for stopped containers)

````
docker ps
````

Build image

````
docker build . -tag myImage
````

Run container (port forwards 80-80) using image myImage

````
docker run --rm -p 80:80 myImage
````

Interact with container using bash as 
````
docker exec -it container_name bash
````

push image to Azure Container Registry
````
az acr login --name myregistry
````

build container for ACR you need to specify the registry name
````
docker tag myImage myregistry.azurecr.io/sample/myImage

docker push myregistry.azurecr.io/samples/myImage
````

/user/x/.docker/config.json
May contain corrupt config with key value of `"credsStore" : "desktop",`
Remove it if you have issues.
