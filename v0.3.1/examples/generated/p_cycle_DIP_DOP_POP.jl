using AIBECS

grd, T_Circulation = OCIM0.load() ;

iwet = indices_of_wet_boxes(grd)
nb = length(iwet)
z = ustrip.(vector_of_depths(grd))
ztop = vector_of_top_depths(grd) ;

DIV = buildDIV(grd)
Iabove = buildIabove(grd) ;

T_DIP(p) = T_Circulation
T_DOP(p) = T_Circulation
T_DO2(p) = T_Circulation
S₀ = buildPFD(ones(nb), DIV, Iabove)
S′ = buildPFD(ztop, DIV, Iabove)
function T_POP(p)
    w₀, w′ = p.w₀, p.w′
    return w₀ * S₀ + w′ * S′
end
T_all = (T_DIP, T_DOP, T_POP, T_DO2) ;

function geores(x, p)
    τg, xgeo = p.τg, p.xgeo
    return (xgeo .- x) / τg
end

relu(x) = (x .≥ 0) .* x
function uptake(DIP, p)
    τu, ku, z₀ = p.τu, p.ku, p.z₀
    DIP⁺ = relu(DIP)
    return 1/τu * DIP⁺.^2 ./ (DIP⁺ .+ ku) .* (z .≤ z₀)
end

function respiration(DOP, p)
    κDOP = p.κDOP
    return κDOP * DOP
end

function dissolution(POP, p)
    κPOP = p.κPOP
    return κPOP * POP
end

h = ustrip(grd.δdepth[1])             # thickness of the top layer
z = grd.depth_3D[iwet]        # depth of the gridbox centers
using WorldOceanAtlasTools
WOA = WorldOceanAtlasTools
μDO2sat , σ²DO2sat = WOA.fit_to_grid(grd,2018,"O2sat","annual","1°","an") ;
DO2sat = vec(μDO2sat)[iwet]
function airsea(DO2, p)
    κDO2 = p.κDO2
    return κDO2 * (z .< 20u"m") .* (DO2sat .- DO2) / h
end

function sms_DIP(DIP, DOP, POP, DO2, p)
    return -uptake(DIP, p) + respiration(DOP, p) + geores(DIP, p)
end
function sms_DOP(DIP, DOP, POP, DO2, p)
    σ = p.σ
    return σ * uptake(DIP, p) - respiration(DOP, p) + dissolution(POP, p)
end
function sms_POP(DIP, DOP, POP, DO2, p)
    σ = p.σ
    return (1 - σ) * uptake(DIP, p) - dissolution(POP, p)
end
function sms_DO2(DIP, DOP, POP, DO2, p)
    rO2P = p.rO2P
    return airsea(DO2,p) + rO2P * (uptake(DIP,p) - respiration(DOP,p))
end
sms_all = (sms_DIP, sms_DOP, sms_POP, sms_DO2,) # bundles all the source-sink functions in a tuple

t = empty_parameter_table()    # initialize table of parameters
add_parameter!(t, :xgeo, 2.17u"mmol/m^3")
add_parameter!(t, :τg, 1.0u"Myr")
add_parameter!(t, :ku, 10.0u"μmol/m^3")
add_parameter!(t, :z₀, 80.0u"m")
add_parameter!(t, :w₀, 1.0u"m/d")
add_parameter!(t, :w′, 1/4.4625u"d")
add_parameter!(t, :κDOP, 1/0.25u"yr")
add_parameter!(t, :κPOP, 1/5.25u"d")
add_parameter!(t, :σ, 0.3u"1")
add_parameter!(t, :τu, 30.0u"d")
add_parameter!(t, :κDO2, 50u"m" / 30u"d")
add_parameter!(t, :rO2P, 175.0u"mol/mol")
initialize_Parameters_type(t, "DIP_DOP_POP_O₂_Parameters")   # Generate the parameter type

nt = length(T_all)    # number of tracers
n = nt * nb           # total dimension of the state vector
p = DIP_DOP_POP_O₂_Parameters() # parameters
x = p.xgeo * ones(n) # initial iterate
F, ∇ₓF = state_function_and_Jacobian(T_all, sms_all, nb)

prob = SteadyStateProblem(F, ∇ₓF, x, p)
nothing # s = solve(prob, CTKAlg()) # Not working yet

DIP, DOP, POP, DO2 = state_to_tracers(x, nb, nt) # remove when line below works
nothing # DIP, DOP, POP, DO2 = state_to_tracers(s.u, nb, nt)

depth = grd.depth
iz = findfirst(depth .> 200u"m")
iz, depth[iz]

DIP_3D = rearrange_into_3Darray(DIP, grd)
DIP_2D = DIP_3D[:,:,iz] * ustrip(1.0u"mol/m^3" |> u"mmol/m^3")
lat, lon = ustrip.(grd.lat), ustrip.(grd.lon)

ENV["MPLBACKEND"]="qt5agg"
using PyPlot, PyCall
clf()
ccrs = pyimport("cartopy.crs")
ax = subplot(projection = ccrs.EqualEarth(central_longitude=-155.0))
ax.coastlines()

lon_cyc = [lon; 360+lon[1]]
DIP_2D_cyc = hcat(DIP_2D, DIP_2D[:,1])

p = contourf(lon_cyc, lat, DIP_2D_cyc, levels=0:0.2:3.6, transform=ccrs.PlateCarree(), zorder=-1)
colorbar(p, orientation="horizontal");
gcf()

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl

