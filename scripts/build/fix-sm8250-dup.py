import re, sys
p = sys.argv[1]
s = open(p).read()
sig = 'static int sm8250_snd_hw_params(struct snd_pcm_substream *substream,'
idx1 = s.find(sig)
idx2 = s.find(sig, idx1 + 1)
print('first at', idx1, 'second at', idx2)
assert idx1 != -1 and idx2 != -1
end = s.find('\n}\n', idx2)
assert end != -1, 'no closing brace'
block = s[idx2:end+3]
print('removing block bytes', len(block))
s = s[:idx2] + s[end+3:]
# remove duplicate .hw_params line (keep only first)
ops = '.hw_params = sm8250_snd_hw_params,'
first = s.find(ops)
second = s.find(ops, first + 1)
if second != -1:
    line_start = s.rfind('\n', 0, second) + 1
    line_end = s.find('\n', second) + 1
    print('removing dup ops line:', repr(s[line_start:line_end]))
    s = s[:line_start] + s[line_end:]
open(p, 'w').write(s)
print('remaining signatures:', s.count(sig))
print('remaining ops lines:', s.count(ops))
