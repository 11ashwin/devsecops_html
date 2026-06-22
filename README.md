Multi-Architecture Builds: You compiled a container image that runs on Apple Silicon (ARM64) while remaining compatible with standard cloud servers.

Secure Deployments: You deployed pods with restricted privileges (dropping capabilities, running as non-root) using DevSecOps best practices.

Advanced Traffic Routing: Instead of relying on basic port-forwarding, you configured an NGINX Ingress Controller to manage external access.

Custom DNS: You modified your local machine's hosts file to resolve a custom domain directly to your isolated cluster.



Isssues Faced 


Here is the documentation of the two sequential `ErrImagePull` / `ImagePullBackOff` issues you encountered, along with their root causes and resolutions. You can use this for your project notes or runbook.

### Issue 1: TLS Certificate Verification Failure

**The Error Log:**

> `Failed to pull image "a05shwin11/devsecops_html:v1.0": Error response from daemon: Get "https://registry-1.docker.io/v2/": tls: failed to verify certificate: x509: certificate signed by unknown authority`

**The Root Cause:**
Minikube was unable to securely connect to Docker Hub to download your image. This happens when working on a corporate network or while connected to a VPN/Proxy (like Zscaler or Cisco AnyConnect). These security tools intercept web traffic and inject their own custom SSL certificates. While your Mac's host operating system trusts these corporate certificates, the isolated Minikube virtual machine does not, causing it to reject the connection as unsafe.

**The Resolutions:**

* **Bypass the network (Recommended for local dev):** Load the locally built Docker image directly into Minikube's cache using `minikube image load a05shwin11/devsecops_html:v1.0`, bypassing the need to download it from the internet entirely.
* **Trust the certificates:** Restart Minikube using the `--embed-certs` flag to force the Minikube VM to inherit your Mac's trusted corporate certificates.
* **Drop the VPN:** Temporarily disconnect from the VPN until the image is successfully pulled and cached by Kubernetes.

---

### Issue 2: Architecture Mismatch (Apple Silicon vs. Intel)

**The Error Log:**

> `Failed to pull image "a05shwin11/devsecops_html:v1.0": no matching manifest for linux/arm64/v8 in the manifest list entries`

**The Root Cause:**
Once the network issue was resolved, Docker Hub rejected the pull request because the requested architecture did not exist. Your Mac uses an M-series Apple Silicon chip, which requires the **`arm64`** architecture. However, the image originally pushed to Docker Hub was built for standard Intel/AMD machines (**`amd64`**). When Kubernetes asked Docker Hub for the `arm64` version of your container, Docker Hub returned a "not found" error.

**The Resolution:**
You utilized Docker Buildx to compile a multi-architecture image. This ensured the container could run natively on your local Mac (`arm64`) while maintaining compatibility with standard cloud infrastructure (`amd64`).

The command used to resolve this was:

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t a05shwin11/devsecops_html:v2.0 --push .

```

After pushing the updated `v2.0` image, the `deployment.yaml` was updated to pull the new tag, allowing the pods to transition successfully into a `Running` state.

### Issue 3: Ingress Traffic Dropped (The Mac Networking Quirk)

**The Symptom:**
After successfully deploying the NGINX Ingress controller and mapping `secure-resume.local` to the Minikube IP in the Mac's `/etc/hosts` file, the URL remained completely unreachable. A `curl -I http://secure-resume.local` command returned absolutely no output, indicating the request was being dropped before it even reached the Kubernetes cluster.

**The Root Cause:**
Because Minikube runs inside an isolated virtual machine (or Docker container) on macOS, its internal IP addresses (e.g., `192.168.49.2`) are strictly internal and unroutable from the Mac's host browser. When the `minikube tunnel` command is executed on a Mac, it bridges this gap by binding the cluster's Ingress directly to the Mac's local loopback address (`127.0.0.1`). Because the `/etc/hosts` file was originally pointing to the unroutable `192.168.x.x` IP, the Mac was sending the web traffic into a network black hole.

**The Resolution:**

1. Modified the Mac's local DNS resolution by editing `sudo nano /etc/hosts` to point the custom domain directly to localhost: `127.0.0.1 secure-resume.local`.
2. Restarted the `minikube tunnel` process.
3. Granted macOS administrator privileges to allow the tunnel to securely bind to the privileged HTTP port `80`.

---

### How Your Traffic Flows in Kubernetes

To understand exactly what happens when you type `http://secure-resume.local` into your browser, it helps to visualize the journey your web request takes through the Kubernetes architecture.

Here is the step-by-step traffic flow for your current setup:

**1. The Browser & Local DNS (The Starting Line)**
You type `http://secure-resume.local` into Chrome/Safari. Your browser asks your Mac, "Where is this?" Your Mac checks its `/etc/hosts` file, sees the entry you added, and translates that domain into the IP address `127.0.0.1` (localhost) on port `80`.

**2. Minikube Tunnel (The Bridge)**
Your request hits port `80` on your Mac. Normally, nothing is listening there. But because `minikube tunnel` is running in the background, it intercepts this request. It acts as a secure bridge, carrying your HTTP request across the boundary from your macOS host machine directly into the isolated Minikube virtual network.

**3. The Ingress Controller (The Traffic Cop)**
The tunnel hands the request directly to the **NGINX Ingress Controller** running inside Kubernetes. The Ingress reads the HTTP header of your request and sees `Host: secure-resume.local`. It checks its routing rules (the `ingress.yaml` file you applied) and finds a match: *"Ah, traffic for secure-resume.local goes to the `resume-service`!"*

**4. The Service (The Internal Load Balancer)**
The Ingress forwards the traffic to your **Service** (`resume-service`). The Service doesn't actually process the web page itself; it is an internal load balancer. It keeps a real-time list of all healthy, running Pods that have the label `app: secure-resume`. If you have 2 replicas running, the Service picks one and forwards the traffic to it.

**5. The Pod & Container (The Destination)**
The traffic finally arrives at one of your **Pods** (e.g., `resume-deployment-5c9fc778c8-2wfvq`). Inside that Pod, your ARM64-compatible Docker container is running an NGINX or Apache web server on port `80`. The container serves up your HTML resume files and sends them all the way back down the chain to your browser.
