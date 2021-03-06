# distutils: language = c++
#
# Coordinate and geometry transformations.

import logging

cimport _cpl
cimport _crs
cimport _csl
cimport _geometry


cdef extern from "ogr_geometry.h" nogil:

    cdef cppclass OGRGeometry:
        pass

    cdef cppclass OGRGeometryFactory:
        void * transformWithOptions(void *geom, void *ct, char **options)


cdef extern from "ogr_spatialref.h":

    cdef cppclass OGRCoordinateTransformation:
        pass


log = logging.getLogger("Fiona")
class NullHandler(logging.Handler):
    def emit(self, record):
        pass
log.addHandler(NullHandler())


cdef void *_crs_from_crs(object crs):
    cdef char *proj_c = NULL
    cdef void *osr = NULL
    osr = _crs.OSRNewSpatialReference(NULL)
    if osr == NULL:
        raise ValueError("NULL spatial reference")
    params = []
    # Normally, we expect a CRS dict.
    if isinstance(crs, dict):
        # EPSG is a special case.
        init = crs.get('init')
        if init:
            auth, val = init.split(':')
            if auth.upper() == 'EPSG':
                _crs.OSRImportFromEPSG(osr, int(val))
        else:
            crs['wktext'] = True
            for k, v in crs.items():
                if v is True or (k in ('no_defs', 'wktext') and v):
                    params.append("+%s" % k)
                else:
                    params.append("+%s=%s" % (k, v))
            proj = " ".join(params)
            log.debug("PROJ.4 to be imported: %r", proj)
            proj_b = proj.encode('utf-8')
            proj_c = proj_b
            _crs.OSRImportFromProj4(osr, proj_c)
    # Fall back for CRS strings like "EPSG:3857."
    else:
        proj_b = crs.encode('utf-8')
        proj_c = proj_b
        _crs.OSRSetFromUserInput(osr, proj_c)
    return osr


def _transform(src_crs, dst_crs, xs, ys):
    cdef double *x, *y
    cdef char *proj_c = NULL
    cdef void *src, *dst
    cdef void *transform
    cdef int i

    assert len(xs) == len(ys)

    src = _crs_from_crs(src_crs)
    dst = _crs_from_crs(dst_crs)

    n = len(xs)
    x = <double *>_cpl.CPLMalloc(n*sizeof(double))
    y = <double *>_cpl.CPLMalloc(n*sizeof(double))
    for i in range(n):
        x[i] = xs[i]
        y[i] = ys[i]

    transform = _crs.OCTNewCoordinateTransformation(src, dst)
    res = _crs.OCTTransform(transform, n, x, y, NULL)

    res_xs = [0]*n
    res_ys = [0]*n

    for i in range(n):
        res_xs[i] = x[i]
        res_ys[i] = y[i]

    _cpl.CPLFree(x)
    _cpl.CPLFree(y)
    _crs.OCTDestroyCoordinateTransformation(transform)
    _crs.OSRDestroySpatialReference(src)
    _crs.OSRDestroySpatialReference(dst)
    return res_xs, res_ys


def _transform_geom(
        src_crs, dst_crs, geom, antimeridian_cutting, antimeridian_offset,
        precision):
    """Return a transformed geometry."""
    cdef char *proj_c = NULL
    cdef char *key_c = NULL
    cdef char *val_c = NULL
    cdef char **options = NULL
    cdef void *src, *dst
    cdef void *transform
    cdef OGRGeometryFactory *factory
    cdef void *src_ogr_geom
    cdef void *dst_ogr_geom
    cdef int i

    if src_crs and dst_crs:
        src = _crs_from_crs(src_crs)
        dst = _crs_from_crs(dst_crs)
        transform = _crs.OCTNewCoordinateTransformation(src, dst)

        # Transform options.
        options = _csl.CSLSetNameValue(
                    options, "DATELINEOFFSET", 
                    str(antimeridian_offset).encode('utf-8'))
        if antimeridian_cutting:
            options = _csl.CSLSetNameValue(options, "WRAPDATELINE", "YES")

        factory = new OGRGeometryFactory()
        src_ogr_geom = _geometry.OGRGeomBuilder().build(geom)
        dst_ogr_geom = factory.transformWithOptions(
                        <const OGRGeometry *>src_ogr_geom,
                        <OGRCoordinateTransformation *>transform,
                        options)
        g = _geometry.GeomBuilder().build(dst_ogr_geom)

        _geometry.OGR_G_DestroyGeometry(dst_ogr_geom)
        _geometry.OGR_G_DestroyGeometry(src_ogr_geom)
        _crs.OCTDestroyCoordinateTransformation(transform)
        if options != NULL:
            _csl.CSLDestroy(options)
        _crs.OSRDestroySpatialReference(src)
        _crs.OSRDestroySpatialReference(dst)
    else:
        g = geom
    if precision >= 0:
        if g['type'] == 'Point':
            x, y = g['coordinates']
            x = round(x, precision)
            y = round(y, precision)
            new_coords = [x, y]
        elif g['type'] in ['LineString', 'MultiPoint']:
            xp, yp = zip(*g['coordinates'])
            xp = [round(v, precision) for v in xp]
            yp = [round(v, precision) for v in yp]
            new_coords = list(zip(xp, yp))
        elif g['type'] in ['Polygon', 'MultiLineString']:
            new_coords = []
            for piece in g['coordinates']:
                xp, yp = zip(*piece)
                xp = [round(v, precision) for v in xp]
                yp = [round(v, precision) for v in yp]
                new_coords.append(list(zip(xp, yp)))
        elif g['type'] == 'MultiPolygon':
            parts = g['coordinates']
            new_coords = []
            for part in parts:
                inner_coords = []
                for ring in part:
                    xp, yp = zip(*ring)
                    xp = [round(v, precision) for v in xp]
                    yp = [round(v, precision) for v in yp]
                    inner_coords.append(list(zip(xp, yp)))
                new_coords.append(inner_coords)
        g['coordinates'] = new_coords

    return g
