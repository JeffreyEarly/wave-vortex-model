import pathlib,re,collections,json,sys
p=pathlib.Path(sys.argv[1]);s=p.read_text().split('Call graph:')[1].split('Total number in stack')[0]
nodes=[];stack=[]
for l in s.splitlines():
 m=re.match(r'^([ +!:|]*)(\d+) (.*)$',l)
 if not m:continue
 prefix,cnt,label=m.groups();depth=len(prefix);cnt=int(cnt)
 while stack and nodes[stack[-1]]['depth']>=depth:stack.pop()
 fn=label.split('  (in ')[0];fn=re.sub(r' \+.*$','',fn)
 n={'thread':(nodes[stack[-1]]['thread'] if stack else len(nodes)), 'depth':depth,'count':cnt,'self':cnt,'fn':fn,'label':label,'parent':stack[-1] if stack else None}
 if stack:nodes[stack[-1]]['self']-=cnt
 nodes.append(n);stack.append(len(nodes)-1)
selfs=collections.Counter();incs=collections.Counter();libraries=collections.Counter();threads=[]
for i,n in enumerate(nodes):
 if n['fn'].startswith('Thread_'):threads.append((n['fn'],n['count']))
 if n['self']<0:raise ValueError(n)
 if not '(in ' in n['label']:continue
 selfs[n['fn']]+=n['self'];incs[n['fn']]+=n['count']
 lib=n['label'].split('(in ',1)[1].split(')',1)[0];libraries[lib]+=n['self']
main=[n for n in nodes if n['thread']==0];mainSelf=collections.Counter();mainInc=collections.Counter()
for n in main:
 if '(in ' in n['label']:mainSelf[n['fn']]+=n['self'];mainInc[n['fn']]+=n['count']
print('Main total',nodes[0]['count']);print('Main exclusive top');print('\n'.join(f'{c} {n}' for n,c in mainSelf.most_common(12)))
print('Threads',len(threads))
print('Libraries exclusive',libraries.most_common(10))
print('Top self');print('\n'.join(f'{c} {n}' for n,c in selfs.most_common(20)))
print('Selected inclusive');print('\n'.join(f'{c} {n}' for n,c in incs.most_common() if any(x in n for x in ['::reconstruct(','::project(','VerticalOperator::execute','HorizontalOperator::inverse','HorizontalOperator::forward','preparePhase','validateState','addAdaptiveDamping','::combine','::findEntry'])))
summary={'mainThreadSamples':nodes[0]['count'],'mainThreadTopExclusive':mainSelf.most_common(30),'mainThreadTopInclusive':mainInc.most_common(45),'threads':threads,'libraryExclusiveSamples':dict(libraries),'topExclusiveSamples':selfs.most_common(30),'selectedInclusiveSamples':[(n,c) for n,c in incs.most_common() if any(x in n for x in ['::reconstruct(','::project(','VerticalOperator::execute','HorizontalOperator::inverse','HorizontalOperator::forward','preparePhase','validateState','addAdaptiveDamping','::combine','::findEntry'])]}
p.with_name('sample-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
