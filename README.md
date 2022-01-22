build watcher: `w4 watch -n`

make sure you aren't over the size limit:
`zig build -Drelease-small && ls -l zig-out/lib/cart.wasm`
(maximum is 65,536 bytes)

recommend also using wasm-opt -Oz because it got likt 50kb → 46kb

check this: `wasm-objdump zig-out/lib/cart.wasm -x -j code`

## ingconv notes

1. scale the image down to 160x160
2. https://www.imgonline.com.ua/eng/limit-color-number.php
3. imgconv image.jpg image.w4i --compress --detect-palette

## bundling

```
zig build -Drelease-small && ls -l zig-out/lib/cart.wasm && w4 bundle zig-out/lib/cart.wasm --html zig-out/lib/file.html
```

note: also use wasm-opt

## TODO:

- [x] finish up the game
  - [x] intro screen. the computer thing and a clicker game → the full game
  - [x] pause menu so you can go back out to the computer. it would be cool to
        have interactions between the game and the computer but idk
  - [x] end screen. you unlock infinite dashes + debug keys
- [ ] see how many desktop backgrounds I can fit in the cart
  - [ ] `wasm-opt -Oz --strip-producers --dce --zero-filled-memory` ← make sure
        to use this, it will make the zig output even smaller
  - [ ] see if we can go right the way up to the limit
  - [ ] oh yeah we could do that before release, why not