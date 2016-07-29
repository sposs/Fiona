"""pytest fixtures and automatic test data generation."""


import json
import os.path
import tarfile
import zipfile

from click.testing import CliRunner
import pytest

import fiona


_COUTWILDRNP_FILES = [
    'coutwildrnp.shp', 'coutwildrnp.shx', 'coutwildrnp.dbf', 'coutwildrnp.prj']


def _read_file(name):
    with open(os.path.join(os.path.dirname(__file__), name)) as f:
        return f.read()


@pytest.fixture(scope='session')
def data_dir():
    """Absolute file path to the directory containing test datasets."""
    return os.path.abspath(os.path.join('tests', 'data'))


@pytest.fixture(scope='session')
def path_coutwildrnp_shp():
    """Path to ```coutwildrnp.shp``"""
    return os.path.abspath(os.path.join(data_dir()))


@pytest.fixture(scope='session')
def path_coutwildrnp_zip():
    """Creates ``coutwildrnp.zip`` if it does not exist and returns the absolute
    file path."""
    path = os.path.join(data_dir(), 'coutwildrnp.zip')
    if not os.path.exists(path):
        with zipfile.ZipFile(path, 'w') as zip:
            for filename in _COUTWILDRNP_FILES:
                zip.write(os.path.join(data_dir(), filename), filename)
    return path


@pytest.fixture(scope='session')
def path_coutwildrnp_tar():
    """Creates ``coutwildrnp.tar`` if it does not exist and returns the absolute
    file path."""
    path = os.path.join(data_dir(), 'coutwildrnp.tar')
    if not os.path.exists(path):
        with tarfile.open(path, 'w') as tar:
            for filename in _COUTWILDRNP_FILES:
                tar.add(
                    os.path.join(data_dir(), filename),
                    arcname='testing/{}'.format(filename))
    return path


@pytest.fixture(scope='session')
def path_coutwildrnp_json():
    """Creates ``coutwildrnp.json`` if it does not exist and returns the absolute
    file path."""
    path = os.path.join(data_dir(), 'coutwildrnp.json')
    if not os.path.exists(path):
        name = _COUTWILDRNP_FILES[0]
        with fiona.open(os.path.join(data_dir(), name), 'r') as source:
            features = [feat for feat in source]
        my_layer = {
            'type': 'FeatureCollection',
            'features': features}
        with open(path, 'w') as f:
            f.write(json.dumps(my_layer))
    return path


@pytest.fixture(scope='session')
def feature_collection():
    """GeoJSON feature collection on a single line."""
    return _read_file('data/collection.txt')


@pytest.fixture(scope='session')
def feature_collection_pp():
    """Same as above but with pretty-print styling applied."""
    return _read_file('data/collection-pp.txt')


@pytest.fixture(scope='session')
def feature_seq():
    """One feature per line."""
    return _read_file('data/sequence.txt')


@pytest.fixture(scope='session')
def feature_seq_pp_rs():
    """Same as above but each feature has pretty-print styling"""
    return _read_file('data/sequence-pp.txt')


@pytest.fixture(scope='session')
def runner():
    """Returns a ```click.testing.CliRunner()`` instance."""
    return CliRunner()