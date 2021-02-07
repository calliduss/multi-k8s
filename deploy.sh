# build all images, tag each one
# since deployment tagged as latest by default we need to use unique tag to distinguish stable version and last changes
# SHA is a good way of tracking the deployments, its defined in .travis.yml
docker build -t calliduss/multi-client:latest -t calliduss/multi-client:$SHA -f ./client/Dockerfile ./client
docker build -t calliduss/multi-server:latest -t calliduss/multi-server:$SHA -f ./server/Dockerfile ./server
docker build -t calliduss/multi-worker:latest -t calliduss/multi-worker:$SHA -f ./worker/Dockerfile ./worker

# push each to Docker Hub
docker push callduss/multi-client:latest
docker push callduss/multi-server:latest
docker push callduss/multi-worker:latest

docker push callduss/multi-client:$SHA
docker push callduss/multi-server:$SHA
docker push callduss/multi-worker:$SHA

# take all configs in k8s directory and apply them
kubectl apply -f k8s

# imperatively set latest images on each deployment
kubectl set image deployments/server-deployments server=calliduss/multi-server:$SHA
kubectl set image deployments/client-deployments client=calliduss/multi-client:$SHA
kubectl set image deployments/worker-deployments worker=calliduss/multi-worker:$SHA