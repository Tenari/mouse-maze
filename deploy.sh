echo "THIS DOESNT DEPLOY THE ZIG SERVER BINARY"
sleep 1
#zig build -Dtarget=x86_64-linux
cd ui
npm run build
cd ../server
ssh root@zapatas.xyz rm -rf ~/src/ui
scp -r ./server/src/ui root@zapatas.xyz:~/src/ui
