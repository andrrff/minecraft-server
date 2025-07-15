# Minecraft Server

This repository provides the necessary configurations to run your own Minecraft server using various methods, including direct execution, Docker, and Kubernetes.

## Prerequisites

Before you begin, you need Java installed on the machine that will host the server. You can check if Java is installed by opening a command prompt or terminal and typing:

```
java -version
```

If it's not installed, you can download it from the official Java website. For Docker and Kubernetes instructions, you will need their respective tools installed.

---

## Method 1: Direct Execution (Standard Method)

This method involves running the server JAR file directly on your machine.

### Getting Started

1.  **Download or Clone this Repository:**
    Get a copy of the files from this repository onto your computer.

2.  **Create a Server Directory:**
    It's a good practice to have a dedicated folder for your Minecraft server. If you've cloned this repository, you're already set. Otherwise, create a new folder and place the downloaded files inside.

3.  **Run the Server for the First Time:**
    You'll need to run the server to generate initial configuration files. Open a command prompt or terminal in your server directory and run the following command, replacing `minecraft_server.jar` with the actual name of the server `.jar` file in this repository:
    ```
    java -jar minecraft_server.jar
    ```

4.  **Accept the EULA:**
    The first run will create a `eula.txt` file. Open this file with a text editor and change `eula=false` to `eula=true`. This indicates you agree to Minecraft's End User License Agreement.

5.  **Start Your Server:**
    Run the same command as in step 3 to start your server. You can also create a startup script (`.bat` on Windows, `.sh` on Linux) with the following content to make it easier to launch and allocate a specific amount of RAM.

    ```bash
    java -Xmx1024M -Xms1024M -jar minecraft_server.jar nogui
    ```

    This command allocates 1 GB of RAM to the server. You can adjust the `1024M` value as needed.

---

## Method 2: Running with Docker

Running a Minecraft server with Docker is a popular way to isolate the server and its dependencies. We will use the widely-used `itzg/minecraft-server` image.

### Steps:

1.  **Install Docker:**
    First, ensure Docker is installed on your machine. You can find installation instructions on the [official Docker website](https://www.docker.com/get-started).

2.  **Pull the Minecraft Server Image:**
    Open your terminal or command prompt and pull the latest Minecraft server Docker image:
    ```bash
    docker pull itzg/minecraft-server
    ```

3.  **Start the Server:**
    To launch the server, you need to run a container from the image. The following command starts a server, accepts the EULA, and exposes the server's port to your local machine.
    ```bash
    docker run -d -p 25565:25565 -e EULA=TRUE --name mc itzg/minecraft-server
    ```
    *   `-d`: Runs the container in "detached" mode (in the background).
    *   `-p 25565:25565`: Maps port 25565 of the container to port 25565 of your machine.
    *   `-e EULA=TRUE`: Sets the environment variable to accept Minecraft's EULA, which is mandatory.
    *   `--name mc`: Assigns an easy-to-remember name to your container.

4.  **Persisting World Data:**
    To ensure your Minecraft world data is not lost when the container is removed, you should use a Docker volume. Create a directory on your machine to store the data and mount it into the container.

    ```bash
    mkdir minecraft-data
    docker run -d -p 25565:25565 -e EULA=TRUE --name mc -v "$(pwd)/minecraft-data:/data" itzg/minecraft-server
    ```    *   `-v "$(pwd)/minecraft-data:/data"`: Mounts the `minecraft-data` directory from your current location to the `/data` directory inside the container, where the world data is stored.

5.  **Managing the Server:**
    *   **Stop the server:** `docker stop mc`
    *   **Start the server again:** `docker start mc`
    *   **View server logs:** `docker logs -f mc`

---

## Method 3: Running with Kubernetes

Running a Minecraft server on Kubernetes is ideal for cloud environments and for those who want automatic orchestration, scalability, and robust management.

### Prerequisites:

*   A running Kubernetes cluster.
*   `kubectl` configured to interact with your cluster.
*   (Optional but recommended) A `StorageClass` for persistent volume provisioning.

### Steps:

1.  **Create Kubernetes Configuration Files:**
    You will need three main Kubernetes components: a `PersistentVolumeClaim` to store world data, a `Deployment` to manage the server pod, and a `Service` to expose the server to the internet.

    Create a file named `minecraft-server.yaml` with the following content:

    ```yaml
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: minecraft-data-pvc
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 5Gi # Adjust storage size as needed
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: minecraft-server-deployment
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: minecraft
      template:
        metadata:
          labels:
            app: minecraft
        spec:
          containers:
          - name: minecraft
            image: itzg/minecraft-server
            ports:
            - containerPort: 25565
              name: minecraft
            env:
            - name: EULA
              value: "TRUE"
            - name: MEMORY
              value: "2G" # Memory allocation for the server
            volumeMounts:
            - name: minecraft-data-storage
              mountPath: /data
          volumes:
          - name: minecraft-data-storage
            persistentVolumeClaim:
              claimName: minecraft-data-pvc
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: minecraft-service
    spec:
      selector:
        app: minecraft
      ports:
        - protocol: TCP
          port: 25565
          targetPort: 25565
      type: LoadBalancer # Uses a LoadBalancer to expose the server externally
    ```

2.  **Deploy to the Kubernetes Cluster:**
    Apply the configuration to your cluster using `kubectl`:
    ```bash
    kubectl apply -f minecraft-server.yaml
    ```

3.  **Check Status and Connect:**
    *   **Check if the pods are running:**
        ```bash
        kubectl get pods
        ```
    *   **Get the External IP Address:**
        Kubernetes will take a moment to provision an external IP address for your `LoadBalancer` service. Check the status with:
        ```bash
        kubectl get service minecraft-service
        ```
        Look for the value under `EXTERNAL-IP`. Once an IP address is listed, you can use it to connect to your server from the Minecraft client.

## Server Configuration

Regardless of the method used, you can customize your server's settings by editing the `server.properties` file. For Docker and Kubernetes, you can pass these settings as environment variables. This file controls:
*   `gamemode`: Set the game mode (e.g., survival, creative).
*   `motd`: The message displayed in the server list.
*   `max-players`: The maximum number of players.
*   `server-port`: The port your server runs on (default is 25565).

## Connecting to Your Server

*   **From the Same Computer (or Localhost):** Use `localhost` as the server address.
*   **From Another Computer on the Same Network:** Use the server's local IP address.
*   **From Outside Your Network (Public Server):** You will need your public IP address. If running on a local machine, you may need to set up port forwarding on your router for port `25565`. When using Kubernetes with a `LoadBalancer`, the external IP provided is already public.
