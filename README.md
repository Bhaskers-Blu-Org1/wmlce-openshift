[//]: # (Licensed Materials - Property of IBM)
[//]: # (5737-E67)
[//]: # (\(C\) Copyright IBM Corporation 2018,2019 All Rights Reserved.)
[//]: # (US Government Users Restricted Rights - Use, duplication or)
[//]: # (disclosure restricted by GSA ADP Schedule Contract with IBM Corp.)

# IBM Watson Machine Learning Community Edition on OpenShift Using Helm Tiller

[IBM Watson Machine Learning Community Edition (WML CE)](https://developer.ibm.com/linuxonpower/deep-learning-powerai/) makes deep learning, machine learning, and AI more accessible and more performant.

## Introduction

IBM WML CE incorporates some of the most popular deep learning frameworks, along with unique IBM augmentations to improve cluster performance and support larger deep learning models. 


## Chart Details

- Deploys a pod with the WML CE container that has all of the supported WML CE frameworks.
- Supports persistent storage, allowing you to access your data sets and provide your training application code to the pod.
- Provides control over the command that is run during pod startup.
- Allows you to control which GPU type is used. Useful when running multiple worker nodes of different GPU types. For example, AC922 with V100 and 822LC with P100.

## Prerequisites

- Kubernetes v1.11.3 or later with GPU scheduling enabled, and Tiller v2.9.1 or later (Refer to the Install Tiller and Helm section)
- The application must run on nodes with *supported GPUs* [see IBM WML CE V1.6.2 release notes](https://developer.ibm.com/linuxonpower/deep-learning-powerai/releases/).  
- Helm 2.9.1 or later 
- Refer to the [Enabling GPUs in OpenShift](https://developer.ibm.com/linuxonpower/2019/11/19/enabling-gpus-in-openshift-3-11/) section to configure on GPU nodes.
- If you wish to leverage persistent storage for data sets and/or runtime code, you should enable `persistence.enabled=true` and create your persistent volume prior to deploying the chart (unless you use `dynamic provisioning`). It can be created by using a yaml file as in the following example:
Note: accessModes can be ReadWriteOnce/ReadWriteMany

```
kind: PersistentVolume
apiVersion: v1
metadata:
  name: "wmlce-datavolume"
  labels:
    type: local
spec:
  storageClassName: ""
  capacity:
    storage: 8Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/wmlce/data"

```
### Enabling GPUs in OpenShift

See https://developer.ibm.com/linuxonpower/2019/11/19/enabling-gpus-in-openshift-3-11/

### Install Tiller and Helm

#### Create a Tiller project
Create a project where the tiller image/service will be deployed.  The name of the project can be anything.  For example, it can be as simple as "tiller".  For the rest of this document, we will use TILLER_PROJECT for the project name.

```
 oc new-project TILLER_PROJECT
```
 
#### Get helm client and copy the binary

- On Power

Copy tiller deployment and service yaml from the prereqs folder:

```
$ wget https://get.helm.sh/helm-v2.12.0-linux-ppc64le.tar.gz
$ tar xvf helm-v2.12.0-linux-ppc64le.tar.gz
$ cp linux-ppc64le/helm /usr/local/bin/

```
- On x86

```
$ wget https://get.helm.sh/helm-v2.12.0-linux-amd64.tar.gz
$ tar xvf helm-v2.12.0-linux-amd64.tar.gz
$ cp linux-amd64/helm /usr/local/bin/

```

#### Start tiller deployment

- On Power

Before starting the tiller deployment, in the tiller-template.yaml file, make sure to update the tiller image name:

```
...
spec:
  containers:
  - name: tiller
     image: <tiller image>
...
```
Replace <tiller image> with the full tiller image name.  For example, ibmcom/tiller-ppc64le:v2.12.0-ocp-3.11

```
oc process -f tiller-template.yaml -p TILLER_NAMESPACE=TILLER_PROJECT -p HELM_VERSION=2.12.0 | oc create -f -
```
- On x86

```
oc process -f https://github.com/openshift/origin/raw/master/examples/helm/tiller-template.yaml -p TILLER_NAMESPACE=TILLER_PROJECT -p HELM_VERSION=v2.12.0 | oc create -f -
```

Next, start the tiller service:
```
oc create -f tiller-service.yaml
```

#### Export HELM_HOST and HELM_HOME
```
export HELM_HOST=tiller.TILLER_PROJECT.svc.cluster.local:44134
```

#### Verify the setup with: helm version

Test that the helm binary can communicate with the tiller service:
```
$ helm version
Client: &version.Version{SemVer:"v2.12.0", GitCommit:"20adb27c7c5868466912eebdf6664e7390ebe710", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.12.0", GitCommit:"d325d2a9c179b33af1a024cdb5a4472b6288016a", GitTreeState:"clean"}
```

#### Adjust SCC (Security Context Constraint)
Bind the cluster-admin cluster role to the TILLER_PROJECT.  This step only needs to be done once per cluster.
````
oc create clusterrolebinding tiller-cluster-admin --clusterrole=cluster-admin --serviceaccount=TILLER_PROJECT:tiller
````

## Resources Required

Generally, WMLCE leverages GPUs for training and inferencing. You can control the number of GPUs a given pod has access to by setting  the `resources.gpu` value.  Setting it to 0 allows deployment on a non-GPU system.
You can also control the GPU-type that is assigned to a given pod by using the `resources.gputype` value. This uses a nodeSelector label of `gputype` (example: gputype=nvidia-tesla-v100-16gb) and needs to be configured before deploying the Helm chart. This is useful when running a mix of GPU-enabled worker nodes, For Example: IBM Power Systems AC922 (POWER9) with V100 GPUs and IBM Power Systems 822LC for HPC (POWER8) with P100 GPUs.

## Limitations

* This chart is intended to be deployed in OpenShift.
* This chart provides some basic building blocks to get started with WML CE.  It is generally expected (though not required) that the WML CE Docker image and Helm chart would be extended for a specific production use case.
* When DDL/Distributed mode with InfiniBand is enabled, IPC_LOCK, SYS_PTRACE, SYS_RESOURCE, and hostPID capabilities will be added.
* Distributed mode can be used to deploy the cluster for all distributed frameworks like DML/DDL.
* In future releases, the `ddl` option will be deprecated.
* DDL/Distributed mode with Infiniband is only supported when all worker nodes are running on RHEL as the host operating system.

## Installing the Chart

1. Clone the repository:
git clone https://github.com/ibm/wmlce-openshift

2. Apply SCC for added capabilities 

Note: If you have plan to enable paiDistributed or DDL, add the below values in the existing wmlce-scc.yaml file:

```
allowHostIPC: true
allowHostNetwork: true
allowHostPID: true
allowHostPorts: true

```

```
oc create -f prereqs/wmlce-scc.yaml
oc adm policy add-scc-to-user <name_of_scc> system:serviceaccount:<TILLER_PROJECT>:default
```

3. Pull the WMLCE image from the Redhat registry.

All WML CE image tags are available at https://access.redhat.com/containers/?tab=tags#/registry.connect.redhat.com/ibm/wmlce.
If you have to check other framework specific image tags, replace wmlce with the framework name in the above link. These frameworks are available: pytorch, tensorflow, rapids, xgboost, caffe, and pai4sk.
Visit the Redhat registry to check for the latest available tags before pulling any image. Use the following commands from a system to pull the image. Make sure to pull the image to all worker nodes.

```
$ docker login registry.connect.redhat.com
Username: ${REGISTRY-SERVICE-ACCOUNT-USERNAME}
Password: ${REGISTRY-SERVICE-ACCOUNT-PASSWORD}

$ docker pull registry.connect.redhat.com/ibm/wmlce:wmlce-1.6.2-py36-<arch>-2

where arch = ppc64le or x86-64
```
The default value wmlce-1.6.2-py36-ppc64le-2 is set in values.yaml. If you want to use differnt tag, update values.yaml with the correct image tag or update the tag during deployment.

4. Install the chart.  In this example, it has the release name `my-release`:

```bash
$ helm install --name my-release --set license=accept <path_of_chart> 
```

The command deploys ibm-wmlce on the OpenShift cluster in the default configuration. The [configuration](#configuration) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list`

## Verifying the Chart

See the NOTES.txt file associated with this chart for verification instructions.

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```bash
$ helm delete my-release --purge 
```

The command removes all the Kubernetes components associated with the chart and deletes the release. After deleting the chart, you should consider deleting any persistent volumes that you created.

For example :

When deleting a release with stateful sets,  the associated persistent volume will need to be deleted.  
Do the following after deleting the chart release to clean up orphaned persistent volumes.


```console
$ oc delete pvc -l release=my-release
```
```console
$ oc delete pv <name_of_pv>
```

## Configuration
The following table lists the configurable parameters of the `ibm-wmlce-dev` chart and their default values.

| Parameter                        | Description                                     | Default                                                    |
| -------------------------------- | ----------------------------------------------- | ---------------------------------------------------------- |
| `license`                        | Set `license=accept` to accept the terms of the license | `Not accepted`                                     |
| `image.repository`               | WMLCE image repository.          | `registry.connect.redhat.com/ibm/wmlce`                       |
| `image.tag`                      | Docker Image tag. To get the tag of other images, visit " https://access.redhat.com/containers/?tab=tags#/registry.connect.redhat.com/ibm/wmlce"                                    | `wmlce-1.6.2-py36-ppc64le-2`                                                        |
| `image.pullPolicy`               | Docker Image pull policy (Options - IfNotPresent, Always, Never)                              | `IfNotPresent`                                             |
| `global.image.secretName`               | Docker Image pull secret, if you are using a private Docker registry | `nil`                                        |
| `service.type`                   | Kubernetes service type for exposing ports (Options - ClusterIP, None)       | `nil`                                  |
| `service.port`                   | Kubernetes port number to expose       | `nil`                                  |
| `resources.gpu`          | Number of GPUs on which to run the container. A value of 0 will not allocate a GPU.  | `1`                                                   |
| `resources.gputype`      | Type of GPU on which to run the container. Requires use of nodeSelector label of gputype to be configured prior. (E.G. gputype=nvidia-tesla-v100-16gb). | `nvidia-tesla-v100-16gb`
| `paiDistributed.mode`            | Enable WMLCE Distributed mode.  | `false`                                                   |
| `paiDistributed.gpuPerHost`            | Number of GPUs per host .  | `4`                                                   |
| `paiDistributed.sshKeySecret`            | Secret containing 'id_rsa' and 'id_rsa.pub' keys for the containers.  | `nil`                                                   |
| `paiDistributed.useHostNetwork`            | For better performance with TCP, use the host network. WARNING: SSH port needs to be different than 22.  | `false`                                                   |
| `paiDistributed.sshPort`            | Port used by SSH.  | `22`                                                   |
| `paiDistributed.useInfiniBand`         | Use InfiniBand for cross node communication. | `false`                                                   |
| `ddl.enabled`            | Enable WMLCE Distributed mode when using DDL.  | `false`                                                   |
| `ddl.gpuPerHost`            | Number of GPUs per host when using DDL.  | `4`                                                   |
| `ddl.sshKeySecret`            | Secret containing 'id_rsa' and 'id_rsa.pub' keys for the containers.  | `nil`                                                   |
| `ddl.useHostNetwork`            | For better performance with TCP, use the host network. WARNING: SSH port needs to be different than 22.  | `false`                                                   |
| `ddl.sshPort`            | Port used by SSH.  | `22`                                                   |
| `ddl.useInfiniBand`         | Use InfiniBand for cross node communication. | `false`                                                   |
| `persistence.enabled`       | Use a PVC to persist data | `false`                                              |
| `persistence.useDynamicProvisioning`        | Use dynamic provisioning for persistent volume | `false`                                                 |
| `wmlcePVC.name`        | Name of volume claim | `datavolume`                                                 |
| `wmlcePVC.accessMode`        | Volume access mode (Options: ReadWriteOnce, ReadWriteMany, ReadOnlyMany) | `ReadWriteMany`                                                 |
| `wmlcePVC.existingClaim`        | Data PVC existing claim name | nil (will create a new claim by default)                                                 |
| `wmlcePVC.storageClassName`     | Data PVC Storage class | nil (uses default cluster storage class for dynamic provisioning)                                            |
| `wmlcePVC.size`              | Data PVC size                          | `8Gi`                                        |
| `command`              | Command need to run inside pod. E.G. /usr/bin/python /wmlce/data/train.py;                           | `nil`

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.
```bash
$ helm install --name my-release --set license=accept resources.gpu=1 <chartname>
``` 

Alternatively, a YAML file that specifies the values for the parameters can be provided while installing the chart.
> **Tip**: The default values are in the values.yaml file of the WMLCE chart.

```bash
$ helm install --name my-release -f values.yaml <chartname>
```

The volume is mounted in /wmlce/data when `persistence.enabled=true`


## Storage

You can optionally provide a persistent volume to the deployment. This volume can hold data that you wish to process, as well as  executables for the command you want to run. For example, if you had Python code that would train a model on a given set of data, this volume would host your Python code as well as your data, and you can run the Python code by specifying the appropriate command.
