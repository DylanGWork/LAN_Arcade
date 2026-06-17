# Native Downloads NFS Migration - 2026-06-17

## What changed

The bulky LAN Arcade native client/download shelf now lives on a dedicated NFS export instead of the VM root disk.

- NFS export: `192.168.1.33:/mnt/tank/LAN_Arcade/native-downloads`
- VM mount: `/srv/lan-arcade/native-downloads`
- Web/download path: `/var/www/html/mirrors/games/downloads/native`
- Local backup retained: `/var/www/html/mirrors/games/downloads/native.local-backup`

`/etc/fstab` now contains:

```text
192.168.1.33:/mnt/tank/LAN_Arcade/native-downloads /srv/lan-arcade/native-downloads nfs4 rw,_netdev,nofail,x-systemd.automount,x-systemd.mount-timeout=30 0 0
/srv/lan-arcade/native-downloads /var/www/html/mirrors/games/downloads/native none bind,nofail,x-systemd.requires-mounts-for=/srv/lan-arcade/native-downloads 0 0
```

## Migration notes

Copied the previous local native shelf to NFS with `rsync -aH --numeric-ids`. Dry-run comparison after the copy returned no changes. File counts matched: 149 files on NFS and 149 files in the local backup. Both shelves were about 17 GB at migration time.

The `webserver` container serves `/mirrors/` from a read-only Docker bind mount. After adding the NFS submount, the container initially saw an empty `native/` mount point because Docker's existing bind mount did not receive the new submount live. Restarting only the `webserver` container fixed visibility:

```sh
sudo docker restart webserver
```

If this mount shape changes again, restart `webserver` after the host mounts are active.

## Verification

- `findmnt /srv/lan-arcade/native-downloads` shows the NFS export mounted read/write.
- `findmnt /var/www/html/mirrors/games/downloads/native` shows the same export backing the web path.
- NFS filesystem reports about 12 TB total with 17 GB used by this shelf.
- HTTP checks through nginx:
  - `/mirrors/games/downloads/native/freeciv/index.html` -> 200, 3204 bytes
  - `/mirrors/games/downloads/native/freeciv/3.2.4/manifest.json` -> 200, 1709 bytes
  - `/mirrors/games/downloads/native/luanti/5.16.1/manifest.json` -> 200, 3784 bytes
  - `/mirrors/games/downloads/native/teeworlds-ddnet/ddnet-19.8.2-teeworlds-0.7.5/manifest.json` -> 200, 3651 bytes
  - ranged read of `/mirrors/games/downloads/native/luanti/5.16.1/luanti-5.16.1-arm64-v8a.apk` -> 206, 1024 bytes
- `npm run qa:static` passed: 88 games scanned, 88 OK, 0 external entrypoint refs.

## Cleanup guidance

Keep `native.local-backup` until Dylan is comfortable the NFS shelf survives reboot and further game intake. After that, reclaim the 17 GB local backup deliberately; do not delete it casually.