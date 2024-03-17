from setuptools import setup, find_packages

setup(
    name='kgc',
    version='0.1.0',
    author='jesse goodier',
    author_email='31039225+jessegoodier@users.noreply.github.com',
    description='A utility to get Kubernetes pod status',
    long_description=open('README.md').read(),
    long_description_content_type='text/markdown',
    url='https://github.com/jessegoodier/kgc',
    packages=find_packages(),
    install_requires=[
        'subprocess32==3.5.4',
        'json5==0.9.5',
        'prettytable==2.1.0',
        'termcolor==1.1.0',
    ],
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: Apache Software License',
        'Programming Language :: Python :: 3.7',
    ],
    python_requires='>=3.7',
    entry_points={
        'console_scripts': [
            'kgc = kgc:main',
        ],
    },
)