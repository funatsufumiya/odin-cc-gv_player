# GV video player for [odin-cc](https://github.com/cc4v/odin-cc)

Using [odin-gv](https://github.com/funatsufumiya/odin-gv). Forked from [v_gvvideo](https://github.com/funatsufumiya/v_gvvideo) (player part).

Compressed texture GPU streaming is supported (DXT1/DXT3/DXT5). You can also use alpha channel (opacity).

![docs/screenshot.png](./docs/screenshot.png)

## Pre-requisites

- Please install [odin-cc](https://github.com/cc4v/odin-cc) first.
- Make sure git submodules are installed (make sure directories not empty)

## Examples

```bash
$ odin run examples/single
$ odin run examples/multiple

# NOTE: you can pass your gv files
#
# $ odin run examples/single -- your_file.gv
# $ odin run examples/multiple -- file1.gv file2.gv file3.gv ...
# $ odin run examples/multiple -- your_dir_containing_gv_files
```

## Note

This repository has recursive git submoduels. So you need `git clone --recursive`.