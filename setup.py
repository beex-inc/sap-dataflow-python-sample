import setuptools

REQUIRED_PACKAGES = [
]

setuptools.setup(
    name="sap-dataflow-python-sample",
    version="1.0",
    description="setup file for dataflow worker",
    author="yusuke.otomo",
    author_email="yusuke.otomo@beex-inc.com",
    url="https://www.beex-inc.com/",
    install_requires=REQUIRED_PACKAGES,
    packages=setuptools.find_packages(),
)
