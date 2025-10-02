# OpenShift Compatibility Guide

## Overview

This image is fully compatible with OpenShift's security constraints, including **arbitrary UID** and **fsGroup GID 0** requirements.

## OpenShift Security Model

OpenShift runs containers with:
- **Arbitrary UID**: Random UID like `1000770000` (not the image's default `1000`)
- **GID 0**: Always runs with root group (GID 0) for security
- **No root access**: Cannot run as UID 0
- **fsGroup restrictions**: Volume mounts use GID 0

## How This Image Handles It

### Critical: Build-Time Permissions ONLY

**⚠️ Runtime `chmod` does NOT work in OpenShift** - the arbitrary UID has no permission to modify directory permissions. All permissions MUST be set at build time.

### AGGRESSIVE Build-Time Permissions Strategy

This image uses **intentionally permissive (777) permissions** to guarantee compatibility across all environments. Security is maintained via OpenShift's PodSecurityPolicies and namespace isolation.

```dockerfile
# Step 1: Ownership to GID 0 (root group) - OpenShift requirement
chown -R ${NB_USER}:0 ${HOME} /usr/local /etc/jupyter

# Step 2: WORLD-WRITABLE on home directory (777)
# This ensures ANY UID can read/write regardless of configuration
chmod -R 777 ${HOME}

# Step 3: Group-writable on system directories
chmod -R g+rwX /usr/local/lib/python*/site-packages /etc/jupyter

# Step 4: SetGID bit on all directories
# New files/directories inherit GID 0 ownership automatically
find ${HOME} -type d -exec chmod g+s {} \;
find /usr/local/lib/python* -type d -exec chmod g+s {} \;
find /etc/jupyter -type d -exec chmod g+s {} \;

# Step 5: Ensure /tmp is world-writable with sticky bit
chmod 1777 /tmp
```

**Why 777?**
- ✅ Works with ANY UID/GID combination
- ✅ No permission denied errors possible
- ✅ OpenShift namespace isolation provides security boundary
- ✅ Simpler than trying to match OpenShift's security model perfectly

**Result**: 
- Guaranteed to work on OpenShift, Kubernetes, Docker, Podman
- Any arbitrary UID can read/write all application directories
- New files automatically inherit proper group ownership
- Zero permission-related failures

### Smart Working Directory Fallback

```bash
Priority 1: /home/jovyan/work (if exists & writable - K8s volume mount)
Priority 2: /home/jovyan/work (if /home/jovyan writable - normal Docker)
Priority 3: /tmp/work (always writable - OpenShift fallback)
```

**Result**: Container always finds a writable working directory.

## Testing on OpenShift

### Verify Permissions

```bash
# Inside container terminal
oc rsh deployment/jupyterlab

# Check UID/GID
id
# Expected: uid=1000770000 gid=0(root) groups=0(root)

# Check home directory access
ls -la /home/jovyan/
# Expected: drwxrwxr-x ... jovyan root ... /home/jovyan/

# Check working directory
pwd
# Expected: /home/jovyan/work (or /tmp/work if volume mount failed)

# Test write access
touch test-file.txt && rm test-file.txt
# Expected: Success
```

### Common Issues & Solutions

#### Issue: "Permission denied" on /home/jovyan

**Cause**: Parent directory `/home/jovyan` not accessible by arbitrary UID

**Why**: Build-time permissions may have been insufficient, or image is old

**Solution**: Container automatically falls back to `/tmp/work`

**Verify**:
```bash
pwd
# Should show: /tmp/work (if /home/jovyan/work failed)
```

#### Issue: "Operation not permitted" when trying chmod in entrypoint

**Cause**: Arbitrary UID cannot modify permissions of directories it doesn't own

**Why This Happens**: Even with GID 0, you can only chmod files/dirs you own

**Solution**: This is EXPECTED behavior. All permissions must be set at build time in Dockerfile. Rebuild image if permissions are wrong.

**DO NOT try to fix at runtime** - it will never work in OpenShift.

#### Issue: "cannot create directory"

**Cause**: Volume mount with wrong permissions

**Solution**: Ensure volume has fsGroup set:
```yaml
spec:
  securityContext:
    fsGroup: 0  # Use root group for OpenShift
```

#### Issue: JupyterLab extensions not loading

**Cause**: Python site-packages not group-writable

**Solution**: Rebuild image (fixed in latest Dockerfile)

## OpenShift Deployment Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jupyterlab
spec:
  template:
    spec:
      # Let OpenShift assign arbitrary UID
      securityContext:
        fsGroup: 0  # Required for volume mounts
        
      containers:
      - name: jupyterlab
        image: ghcr.io/liveaverage/pyrrhus-jupyter:cuda-12.1
        
        # Don't override securityContext - use OpenShift defaults
        
        volumeMounts:
        - name: work-volume
          mountPath: /home/jovyan/work
          
      volumes:
      - name: work-volume
        emptyDir: {}
```

## Security Notes

**Q: Isn't 777 insecure?**

**A:** In this context, it's safe because:
1. OpenShift enforces namespace isolation - pods can't access each other's filesystems
2. Each pod runs in its own isolated container
3. PodSecurityPolicies control what the container can do
4. The filesystem is ephemeral (lost on pod restart unless using PVCs)
5. Network policies control ingress/egress
6. RBAC controls API access

The 777 permissions only matter **within** the container. OpenShift's security is at the pod/namespace level, not filesystem permissions.

**Q: What about production?**

**A:** This is appropriate for ephemeral development/notebook environments where:
- Pods are short-lived
- Data is not sensitive or is in mounted secrets/configmaps
- Each user gets their own isolated namespace
- Convenience and "just works" is prioritized

For long-lived production apps with persistent data, use PVCs with proper fsGroup settings.

## Verification Checklist

After deployment, verify:

- [ ] Container starts without permission errors
- [ ] `id` shows arbitrary UID with GID 0
- [ ] `/home/jovyan` is accessible (ls works)
- [ ] Working directory is writable (touch test works)
- [ ] JupyterLab UI loads correctly
- [ ] Notebooks can be created/saved
- [ ] GPU extensions load (if GPU cluster)
- [ ] No "Permission denied" errors in logs

## References

- [OpenShift Guidelines for Creating Images](https://docs.openshift.com/container-platform/latest/openshift_images/create-images.html)
- [Support Arbitrary User IDs](https://docs.openshift.com/container-platform/latest/openshift_images/create-images.html#use-uid_create-images)

