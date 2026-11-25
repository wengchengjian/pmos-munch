import struct, sys, os
img = sys.argv[1]
outdir = sys.argv[2]
os.makedirs(outdir, exist_ok=True)
data = open(img, 'rb').read()
magic, total, hdr, ent_size, ent_cnt, ent_off, page, ver = struct.unpack_from('>8I', data, 0)
print(hex(magic), 'total', total, 'entries', ent_cnt, 'page', page)
for i in range(ent_cnt):
    off = ent_off + i*ent_size
    dt_size, dt_off, did, rev = struct.unpack_from('>4I', data, off)
    print(i, 'size', dt_size, 'off', hex(dt_off), 'id', hex(did), 'rev', hex(rev))
    chunk = data[dt_off:dt_off+dt_size]
    open(os.path.join(outdir, f'{i:02d}_{did:08x}.dtb'), 'wb').write(chunk)
