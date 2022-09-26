# podman-wasm
This repository was inspired by the anouncement of [the talk of Chris Crone and Michael Yuan at Cloud Native Wasm Day North America 2022](https://sched.co/1AUDh) (See [tweet](https://twitter.com/0xE282B0/status/1573581756556533761?s=20&t=Z9vCkTv56lLs9UOLZzEk2A)). It contains a Podman machine image that can run native WebAssembly container images, which only contain wasm files and no runtime. You can find an example for such an image and how to create it [in the wasmedge book](https://wasmedge.org/book/en/use_cases/kubernetes/demo/wasi.html).

## How it works
Podman machine creates a CoreOS QEMU VM to run podman. CoreOS has podman already installed, it uses containerd and crun to run OCI containers. Crun can also run WebAssembly but it needs to be enabled during compiletime. Therefore we build a version of crun with WasmEdge as WebAssembly runtime and put it together with the WasmEdge libs in the VM image for podman machine.

Crun uses annotations to distinguish between standard linux and wasm-containers. The annotations are `module.wasm.image/variant=compat` or `run.oci.handler=wasm` when running a wasm-container with podman it always need an annotation like this `--annotation run.oci.handler=wasm` (see example).

## How to use
### Install Podman
If you haven't already done you need to install [podman](https://podman.io/). To do so, you can use the [Podman Installation Instructions](https://podman.io/getting-started/installation).
### Use patched image on Intel CPU
```bash
podman machine init --image-path https://github.com/KWasm/podman-wasm/releases/download/36.20220906.3.2/fedora-coreos-36.20220906.3.2-qemu.x86_64.qcow2.xz
podman machine start
```
### Use patched image on ARM CPU (M1/M2)
```bash
podman machine init --image-path https://github.com/KWasm/podman-wasm/releases/download/36.20220906.3.2/fedora-coreos-36.20220906.3.2-qemu.aarch64.qcow2.xz
podman machine start
```
### Test the installation
```bash
podman run --rm --annotation module.wasm.image/variant=compat-smart docker.io/wasmedge/example-wasi:latest  /wasi_example_main.wasm 50000000
```


## How to build
Prerequisits:
You'll need [podman](https://podman.io/) and a URL to the qcow2 image you want to modify. The image URL can be found [on the fedora website](https://getfedora.org/en/coreos/download?tab=metal_virtualized). Make sure, that you are yusing a QEMU image (*.qcow2.xz) and that it matches your host architecture (e.g. aarch64 or x86_64).

```bash
export IMAGE_URL=https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/36.20220906.3.2/x86_64/fedora-coreos-36.20220906.3.2-qemu.x86_64.qcow2.xz
export IMAGE_FILENAME=$(basename -s .xz $IMAGE_URL)

# create new instaler image
podman build . -t kwasm/podman-wasm:image-installer
# use installer to download image and install wasmedge
podman run -v $(pwd):/work kwasm/podman-wasm:image-installer /entrypoint.sh $IMAGE_URL 
# if you are using podman machine already to create the new image you need to remove the existing VM
podman machine stop
podman machine rm
# create vm from modified image
podman machine init --image-path $IMAGE_FILENAME
# start virtual machine
podman machine start
# run test image
podman run --rm --annotation module.wasm.image/variant=compat-smart docker.io/wasmedge/example-wasi:latest  /wasi_example_main.wasm 50000000
```

## Troubleshooting
### basename command not found
If you get a message on MacOS that there is no command `basename` you can istall `coreutils` via [Homebrew](https://brew.sh/)
```bash
brew install coreutils
```

### libguestfs: no ldconfig
`/assets/install_wasmedge.guestfish:5: libguestfs: error: command: /ostree/deploy/fedora-coreos/deploy/a8b4dda3092f20335cd3270db131f782edf5cad8b11b927283b3da2af42463e6.0/sbin/ldconfig: No such file or directory`

You can only build images for your architecture. Double check that the image you are using matches your processor architecture.

### Wasm container does not run
`WARNING: image platform ({amd64 linux  [] }) does not match the expected platform ({arm64 linux  [] })
{"msg":"exec container process /wasi_example_main.wasm: Exec format error","level":"error","time":"2022-09-29T19:20:23.000050351Z"}`

The error message `Exec format error` means that the OCI runtime cant execute the entrypoint. That can be the case if a non patched crun is used (default) or if the annotation is missing that indicates that a wasm-image is used. Double check the annotations and the podman machine VM image you use.