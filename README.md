# Knative for serverless apps
We'll provide a 'basic' example of getting a cluster ready for running 'serverless' workloads. The example includes everything you need to setup/configure a GKE cluster, deploy a serverless app, and deploy an event source. This was sewn together from the numerous great examples and tutorials available from google, knative, and nodejs.

BTW in case you're not familiar with 'serverless', it doesnt actually mean there's no server, it just means that you don't manage it, knative will spin up or spin down instances of your app as necessary so you don't need to worry as much about infrastructure.

Apologies in advance for the mish-mash of UI, and command line tools we're using in this example.

If you wanna run this example on windows you can do so if you use `Windows Subsystem for Linux`, that's how I roll at least.

## A note about versions
This example was created with versions...
- GKE: `1.15.12-gke.2`
- Knative: `v0.15.0`
- istio: `1.2.10-*`

The various components we're using are in very active development so no guarantees that it'll work if you use newer versions ^_^

## Pre-requisites
- Some familiarity with google cloud console, at least be able to login and select your sandbox project
- A sandbox google project where you are an owner or at least have the following roles
    - `Editor`
    - `Project IAM Admin`
    - `Kubernetes Engine Admin`
    - `Service Account Admin`
    - As long as you have the `Project IAM Admin` role you can grant yourself the other roles necessary through cloud console's UI
- You might need to enable some google APIs as you go (you'll encounter errors that tell you you need a particular API)
    - You can do that from the side menu under `API & Services` -> `Library`
- gcloud
    - https://cloud.google.com/sdk/install
- docker
    - https://docs.docker.com/get-docker/
- terraform
    - https://learn.hashicorp.com/terraform/getting-started/install
- kubectl
    - https://kubernetes.io/docs/tasks/tools/install-kubectl/
- nodejs

## Some variables to set
We'll be referencing some variables like `$VARIABLE_NAME` in the below steps. Here are all the ones we care about and the default value to set by pasting this into your console, **BE SURE TO REPLACE PROJECT ID WITH YOUR PROJECT**:

    export PROJECT_ID=sandbox-12301230-1230z0  <-------- replace me bro
    export CLUSTER_NAME=ol-dirty-k8
    export ZONE=us-central1-c

    export TF_VAR_project_id=$PROJECT_ID
    export TF_VAR_cluster_name=$CLUSTER_NAME
    export TF_VAR_zone=$ZONE

**Note the TF_VAR ones are for terraform to use, we wont otherwise directly use them**

## Set up the infrastructure
We use `terraform` to create and manage various GCP resources. This allows for a consistently reproducible base environment. In fact this whole example could be further simplified with some additional terraform stuff but I am newb.

From there on we interact directly with kubernetes via `kubectl`. We set up the knative stuff, google's knative connector for pub/sub, and our service mesh (istio). Again, tried to keep it reproducible by defining as much as possible in the kubernetes manifests.

- Make sure your gcloud cli is fully updated or you might run into trouble down the line `gcloud components update`
- Optionally create a new gcloud config via `gcloud init` and set it up for your sandbox project
- Be sure to activate the configuration for your sandbox project
    - `gcloud config configurations activate sandbox-lnguyen` <----- replace the last part with your config name
- And we'll set a few default config values
    - `gcloud config set run/cluster $CLUSTER_NAME`
    - `gcloud config set run/cluster_location $ZONE`
    - `gcloud config set compute/zone $ZONE`
- Create a new service account to use `IAM & Admin` -> `Service Accounts`
    - The name should be: `knative-example-sa`
    - Grant it the role
        - `Editor`
    - After you complete creation click three dots under actions for your service account
    - Click `Create Key` and choose `json`
    - Save that generated file as `terraform/knative-example-sa-creds.json`
- Navigate to the terraform directory in your console and run...
    - `terraform init`
    - `terraform plan`
    - `terraform apply`
- (Might want to grab a coffee or something here) That will run off and create your kubernetes cluster + a pub sub topic
- You can check out your new cluster from the menu `Kubernetes Engine` -> `Clusters` in google cloud console
- Pull credentials from google so that your kubectl tool can connect properly
    - `gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE`
    - Verify your context includes your expected project id / cluster name
        - `kubectl config current-context`
    - Otherwise set your context
        - `kubectl config set-context gke_${PROJECT_ID}_${ZONE}_${CLUSTER_NAME}`
- In the root directory of this repo...
- Install knative operator
    - `kubectl apply -f https://github.com/knative/operator/releases/download/v0.15.0/operator.yaml`
- Deploy knative serving components
    - `kubectl apply -f kubernetes_manifests/knative-serving.yaml`
    - verify with `kubectl get deployment -n knative-serving` that it's all ready
- Deploy knative eventing components
    - `kubectl apply -f kubernetes_manifests/knative-eventing.yaml`
    - verify with `kubectl get deployment -n knative-eventing` that it's all ready
- Setup your DNS using xip.io - this allows you to connect to any knative service via a magic URL
    - `kubectl apply --filename https://storage.googleapis.com/knative-nightly/serving/latest/serving-default-domain.yaml`
- Install knative-gcp
    - Be sure you've updated your gcloud cli `gcloud components update`
    - Install custom resource definitions
        - `kubectl apply --selector events.cloud.google.com/crd-install=true --filename https://github.com/google/knative-gcp/releases/download/v0.15.0/cloud-run-events.yaml`
    - Annnd the rest
        - `kubectl apply --filename https://github.com/google/knative-gcp/releases/download/v0.15.0/cloud-run-events.yaml`
    - Then we have to run a little thing which sets up the workload identity
        - `./hack/init_control_plane_gke.sh`
- And finally setup a local cluster gateway so that serving and eventing components you create can talk to eachother across namespaces
    - `k apply -f kubernetes_manifests/istio-system/istio-1.4.9-knative-extras.yaml`

## Create your consumer node app

Here you create an image containing a webserver that can ingest events. You can use any webserver image you want so long as it sends `200` responses for `POST` requests at `/`

- Navigate to the `pub-sub-consumer` folder
- Install the node depedencies
    - `npm install`
- Feel free to modify `app.js` file where the endpoints of the app live if you wanna try anything out
    - `npm start` will run your server locally and you can access it at `localhost:8080`
- Build your image
    - `docker build -t pub-sub-consumer .`
- Next we'll authenticate with google and push our image to their cloud registry but feel free to push your container elsewhere
    - `gcloud auth configure-docker gcr.io`
    - `docker tag pub-sub-consumer gcr.io/$PROJECT_ID/pub-sub-consumer`
    - `docker push gcr.io/$PROJECT_ID/pub-sub-consumer`
- In the Cloud console UI open `Container Registry`
    - Under images verify that you see your one new image as expected and that it's correctly in your sandbox env
    - Now switch the container registry host visibility to public
        - or someone come add using the service accounts creds to this example with the knative components cuz i'm like O.O
- Your app is ready to be deployed!

## Deploy your consumer app

This sets up your app to run. The underlying instance it runs on is managed by knative and will autoscale down to zero instances when not in use.

- In `kubernetes_manifests/pub-sub-consumer.yaml` replace the container image URL so that it points to your image
    - `sed -i "s/__PROJECT_ID__/$PROJECT_ID/" kubernetes_manifests/pub-sub-consumer.yaml`
- Deploy your app
    - `kubectl apply --filename kubernetes_manifests/pub-sub-consumer.yaml`
- Check the readiness of your serving components with
    - `kubectl get all --namespace pub-sub-consumer`
    - Take note of the URL you see under some of the entries.
- Try hitting the `/ping` endpoint with a request once your service is ready at the URL found above
    - It'll look like ... `http://pub-sub-consumer.pub-sub-consumer.35.194.47.248.xip.io/ping`
- You can tail the logs of your app to see the raw output
    - `kubectl logs -f -n pub-sub-consumer -l serving.knative.dev/service=pub-sub-consumer -c pub-sub-consumer`

## Deploy your event source

This 'source' is really a connector that let's you interact with an external event stream from within kubernetes. In this case our external source is a google pub/sub topic. The event source will invoke our consumer app each time an event gets published.

- Setup the namespace and kubernetes service account for the source
    - `kubectl apply --filename kubernetes_manifests/pub-sub-source/pub-sub-source-service-account.yaml`
- Add role binding for the kubernetes service account
    - `gcloud iam service-accounts add-iam-policy-binding --role roles/iam.workloadIdentityUser --member serviceAccount:$PROJECT_ID.svc.id.goog[pub-sub-source/pub-sub-source-sa] cloud-run-events@$PROJECT_ID.iam.gserviceaccount.com`
- Annontate the service account so it knows it's got some more access
    - `kubectl annotate serviceaccount pub-sub-source-sa iam.gke.io/gcp-service-account=cloud-run-events@$PROJECT_ID.iam.gserviceaccount.com -n pub-sub-source`
- Deploy the source
    - `kubectl apply --filename kubernetes_manifests/pub-sub-source/pub-sub-source.yaml`
    - Verify everything proceeds to the ready state
        - `kubectl -n pub-sub-source get all`
- Now publish a test message
    - `gcloud pubsub topics publish ol-dirty-topic --message='{"weeeeeeeeeeeeeee": "eeeeee"}'`
- Verify that your consumer received and processed the message
    - `kubectl logs -f --tail=50 --selector serving.knative.dev/service=pub-sub-consumer -n pub-sub-consumer -c pub-sub-consumer`
    - If you dont see your message check the event source's output for errors
        - `kubectl logs --tail=50 -n pub-sub-source --selector internal.events.cloud.google.com/pullsubscription=pub-sub-source -c receive-adapter`
- And you're done!

## Clean Up
- Delete various things through cloud console...
    - GKE cluster
    - two service accounts that we created (`cloud-run-events` and `knative-example-sa`)
    - images you pushed to the google container registry
- Don't leave it running for no reason or it'll run up your bill yo
