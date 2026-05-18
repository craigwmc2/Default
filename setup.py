import urllib.request, zipfile, io, os, shutil
url = 'https://github.com/craigwmc2/Default/archive/refs/heads/main.zip'
print('Downloading Cookbook...')
data = urllib.request.urlopen(url).read()
print('Extracting...')
z = zipfile.ZipFile(io.BytesIO(data))
z.extractall('.')
top = sorted(set(n.split('/')[0] for n in z.namelist() if '/' in n))[0]
if os.path.exists('cookbook'):
    shutil.rmtree('cookbook')
os.rename(top, 'cookbook')
print('Done! Now run:')
print('  cd cookbook')
print('  pip install flask requests')
print('  python3 app.py')
