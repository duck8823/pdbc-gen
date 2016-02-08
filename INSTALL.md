# install
```sh
$ perl Makefile.PL
$ make
$ make install
```
  
### prefixの指定
```sh
$ perl Makefile.PL PREFIX=/path/to/install
$ make
$ make install
$ export PERL5LIB=$PERL5LIB:/path/to/install
```

### Windowsの場合
```sh
$ perl Mailefile.PL
$ dmake
$ dmake install
```