module OCIM1
#=
This module serves to load the OCIM matrix and grid.
These are loaded from the public, persistant URL in FigShare.
The Julia JLD2 format version of the OCIM was created with the code
in the GitHub repository https://github.com/briochemc/MatricesForJAMES.
The citation material is in here but I could make it availabe to future JAMES users.
Need to decide if JAMES is the name I want to keep too.
=#

using SparseArrays          # For sparse matrix
using DataDeps              # For storage location of data
using BSON                  # For saving circulation as BSON format
using Unitful, UnitfulAstro # for units
using Reexport
@reexport using OceanGrids            # To store the grid

function fallback_download(remotepath, localdir)
    @assert(isdir(localdir))
    filename = basename(remotepath)  # only works for URLs with filename as last part of name
    localpath = joinpath(localdir, filename)
    Base.download(remotepath, localpath)
    return localpath
end

# Create registry entry for OCIM in JLD2 format
function register_OCIM1()
    register(
        DataDep(
            "AIBECS_OCIM1",
            """
            References:
            - DeVries, T., 2014: The oceanic anthropogenic CO2 sink: Storage, air‐sea fluxes, and transports over the industrial era, Global Biogeochem. Cycles, 28, 631–647, doi:10.1002/2013GB004739.
            - DeVries, T. and F. Primeau, 2011: Dynamically and Observationally Constrained Estimates of Water-Mass Distributions and Ages in the Global Ocean. J. Phys. Oceanogr., 41, 2381–2401, https://doi.org/10.1175/JPO-D-10-05011.1
            """,
            "https://files.figshare.com/15448595/OCIM1.bson",
            sha2_256,
            fetch_method = fallback_download
        )
    )
    return nothing
end

"""
    load

Returns wet3d, grd, and T (in that order) from FigShare repository.
"""
function load()
    print("Loading OCIM1")
    register_OCIM1()
    bson_file = @datadep_str string("AIBECS_OCIM1/", "OCIM1.bson")
    BSON.@load bson_file T grid wet3D
    println(" ✔")
    println("""
            You are about to use the OCIM1, for which the references to cite are:

            - DeVries, T., 2014: The oceanic anthropogenic CO2 sink: Storage, air‐sea fluxes, and transports over the industrial era, Global Biogeochem. Cycles, 28, 631–647, doi:10.1002/2013GB004739.

            - DeVries, T. and F. Primeau, 2011: Dynamically and Observationally Constrained Estimates of Water-Mass Distributions and Ages in the Global Ocean. J. Phys. Oceanogr., 41, 2381–2401, https://doi.org/10.1175/JPO-D-10-05011.1

            You can find the corresponding BibTeX entries in the CITATION.bib file at the root of the AIBECS.jl package repository, with the keys "DeVries_Primeau_2011" and "DeVries_2014".
            """)
    return wet3D, grid, ustrip.(T)
end

end # end module

export OCIM1

