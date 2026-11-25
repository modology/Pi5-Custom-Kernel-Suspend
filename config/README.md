# Kernel configuration

The build expects the full tested kernel configuration at:

`config/bcm2712_tumtum.config`

This is the captured `/lib/modules/6.18.65+/build/.config` from the test Pi. It is intentionally not replaced with a generic defconfig: using the captured configuration is important for reproducing the tested build.

Copy it from the verified export archive:

```bash
mkdir -p config
tar -xzf ~/Downloads/pi5-kernel-export.tar.gz \
  --strip-components=1 \
  -C /tmp pi5-kernel-export/running-kernel.config
cp /tmp/running-kernel.config config/bcm2712_tumtum.config
sha256sum config/bcm2712_tumtum.config
```

Expected SHA-256:

```
396c4e41854080b0cc37fba54c2ced3aa20e3b0c136593cfad092e0110a42792
```

Then commit and push the file:

```bash
git add config/bcm2712_tumtum.config
git commit -m "Add tested Raspberry Pi 5 kernel config"
git push
```

Do not edit the captured config without documenting the changes and retesting the resulting kernel.
