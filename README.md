build watcher: `w4 watch -n`

make sure you aren't over the size limit:
`zig build -Drelease-small && ls -l zig-out/lib/cart.wasm`
(maximum is 65,536 bytes)