# Kubernetes manifests for knative example
Note that each file or subfolder in this folder represents a separate namespace in our example cluster.

- knative-serving - the components supporting serverless apps
- knative-eventing - the components for receiving and processing events
- istio-system - the namespace has various service mesh stuff, but we just provide a cluster local gateway to allow internamespace communication
- pub-sub-source provides the mechanism for getting google pub/sub events in kubernetes.
- pub-sub-consumer is what gets called each time a pub sub message comes in

