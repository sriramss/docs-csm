# Non-Compute Node Images

There are several flavors of NCN images, each share a common base image. When booting NCNs an admin or user will need to choose between
stable (Release) and unstable (pre-release/dev) images.

> For details on how these images behave and inherit from the base and common images, see [node-image-docs][1].

In short, each application image (i.e. kubernetes and storage-ceph) inherit from the non-compute-common layer. Operationally these are all
that matter; the common layer, kubernetes layer, ceph layer, and any other new application images.

To boot an NCN, you need 3 artifacts:

1. The NCN Common initrd and kernel ([stable][2] or [unstable][3])
    - `initrd-img-[RELEASE].xz`
    - `$version-[RELEASE].kernel`
2. The Kubernetes SquashFS ([stable][4] or [unstable][5])
    - `kubernetes-[RELEASE].squashfs`
3. The CEPH SquashFS ([stable][6] or [unstable][7])
    - `storage-ceph-[RELEASE].squashfs`

> NOTE: The application stable and unstable images are all built atop the latest _stable_ NCN common. It is very uncommon to want the unstable NCN images.

[1]: https://stash.us.cray.com/projects/CLOUD/repos/node-image-docs/browse
[2]: http://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/non-compute-common
[3]: http://arti.dev.cray.com/artifactory/node-images-unstable-local/shasta/non-compute-common
[4]: http://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes
[5]: http://arti.dev.cray.com/artifactory/node-images-unstable-local/shasta/kubernetes
[6]: http://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph
[7]: http://arti.dev.cray.com/artifactory/node-images-unstable-local/shasta/storage-ceph

