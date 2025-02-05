/**
 * @author     : Yue Chang (yuechang@pku.edu.cn)
 * @date       : 2021-08-04
 * @description: Declaration of DensitySummationMesh class, which implements the density summation using semi-analytical boundary conditions
 *               introduced in the paper <Semi-analytical Solid Boundary Conditions for Free Surface Flows>
 * @version    : 1.1
 */
#include <cuda_runtime.h>
#include "DensitySummationMesh.h"
#include "Framework/Framework/MechanicalState.h"
#include "Framework/Framework/Node.h"
#include "Core/Utility.h"
#include "Kernel.h"
#include "Framework/Topology/Primitive3D.h"

namespace PhysIKA {
IMPLEMENT_CLASS_1(DensitySummationMesh, TDataType)

__device__ inline float kernWeightMeshPBD(const float r, const float h)
{
    const Real q = r / h;
    if (q > 1.0f)
        return 0.0f;
    else
    {
        //G(r) in equation 6
        const Real d  = 1.0 - q;
        const Real hh = h * h;
        return 15.0f / (( Real )M_PI * hh * h) * (1.0f / 3.0f * (hh * h - r * r * r) - 3.0f / 4.0f / h * (hh * hh - r * r * r * r) + 3.0f / 5.0f / hh * (hh * hh * h - r * r * r * r * r) - 1.0f / 6.0f / hh / h * (hh * hh * hh - r * r * r * r * r * r));
    }
}
/**
 * Computes density of each particle
 * Contributions from neighboring particles and mesh triangles are taken into account
 */
template <typename Real, typename Coord>
__global__ void K_ComputeDensityMesh(
    DeviceArray<Real>                     rhoArr,
    DeviceArray<Coord>                    posArr,
    DeviceArray<TopologyModule::Triangle> Tri,
    DeviceArray<Coord>                    positionTri,
    NeighborList<int>                     neighbors,
    NeighborList<int>                     neighborsTri,
    Real                                  smoothingLength,
    Real                                  mass,
    Real                                  sampling_distance,
    int                                   use_mesh,
    int                                   use_ghost,
    int                                   Start)
{
    int pId = threadIdx.x + (blockIdx.x * blockDim.x);
    if (pId >= posArr.size())
        return;
    //if (pId >= Start)  return;

    SpikyKernel<Real> kern;
    Real              r;
    Real              rho_i = Real(0);
    Real              rho_tmp;
    Coord             pos_i = posArr[pId];

    int nbSizeTri = neighborsTri.getNeighborSize(pId);
    int nbSize    = neighbors.getNeighborSize(pId);

    //printf("%d\n", nbSizeTri);
    if (use_mesh && pId < Start)
        for (int ne = 0; ne < nbSizeTri; ne++)
        {
            int j = neighborsTri.getElement(pId, ne);
            if (j >= 0)
                continue;
            j *= -1;
            j--;

            //printf("j = %d\n", j);
            Triangle3D t3d(positionTri[Tri[j][0]], positionTri[Tri[j][1]], positionTri[Tri[j][2]]);
            Plane3D    PL(positionTri[Tri[j][0]], t3d.normal());
            Point3D    p3d(pos_i);
            //Point3D nearest_pt = p3d.project(t3d);
            Point3D nearest_pt = p3d.project(PL);
            Real    r          = (nearest_pt.origin - pos_i).norm();
            //r = max((r - sampling_distance / 2.0), 0.0);

            Real  AreaSum     = p3d.areaTriangle(t3d, smoothingLength);  //A_s in equation 10
            Real  MinDistance = abs(p3d.distance(t3d));                  //d_n (scalar) in equation 10
            Coord Min_Pt      = (p3d.project(t3d)).origin - pos_i;       //d_n (vector) in equation 10
            Coord Min_Pos     = p3d.project(t3d).origin;
            if (ne < nbSizeTri - 1 && neighborsTri.getElement(pId, ne + 1) < 0)
            {
                int jn;
                //triangle clustering
                do
                {
                    jn = neighborsTri.getElement(pId, ne + 1);
                    //printf("jn = %d\n", jn);
                    if (jn >= 0)
                        break;
                    jn *= -1;
                    jn--;

                    Triangle3D t3d_n(positionTri[Tri[jn][0]], positionTri[Tri[jn][1]], positionTri[Tri[jn][2]]);
                    if ((t3d.normal().cross(t3d_n.normal())).norm() > EPSILON)
                        break;

                    AreaSum += p3d.areaTriangle(t3d_n, smoothingLength);

                    if (abs(p3d.distance(t3d_n)) < abs(MinDistance))
                    {
                        MinDistance = (p3d.distance(t3d_n));
                        Min_Pt      = (p3d.project(t3d_n)).origin - pos_i;
                        Min_Pos     = (p3d.project(t3d_n)).origin;
                    }
                    //printf("%d %d %d\n", j, jn, ne);
                    ne++;
                } while (ne < nbSizeTri - 1);
            }
            Min_Pt /= (-Min_Pt.norm());
            //printf("OK\n");
            float d = p3d.distance(PL);
            d       = abs(d);
            // equation 6
            if (smoothingLength - d > EPSILON && smoothingLength * smoothingLength - d * d > EPSILON && d > EPSILON)
            {

                Real a_ij =
                    kernWeightMeshPBD(r, smoothingLength)
                    * 2.0 * (M_PI) * (1 - d / smoothingLength)
                    * AreaSum  // p3d.areaTriangle(t3d, smoothingLength)
                    / ((M_PI) * (smoothingLength * smoothingLength - d * d))
                    * t3d.normal().dot(Min_Pt) / t3d.normal().norm()  /// (p3d.project(t3d).origin - p3d.origin).norm()
                    / (sampling_distance * sampling_distance * sampling_distance) * kern.m_scale;
                rho_i += 1.0 * mass * a_ij;

                //printf("%.3lf %.3lf %.3lf  %.3lf  %.3lf, %.3lf\n",
                //	r, a_ij, kern.Weight(r, smoothingLength), r, smoothingLength, kern.m_scale);
            }
        }
    if (rho_i < 0)
        rho_i *= -1;
    rho_tmp = rho_i;

    //printf("????????\n");
    bool tmp = false;

    for (int ne = 0; ne < nbSize; ne++)
    {
        int j = neighbors.getElement(pId, ne);

        if (j >= Start && (!use_ghost))
            continue;
        //if (j >= Start) continue;
        if (j >= Start)
            tmp = true;

        if (j >= Start && pId % 10000 == 0 && pId < Start)
        {
            //	printf("%d :%.3lf %.3lf %.3lf\n",pId , posArr[j][0], posArr[j][1], posArr[j][2]);
        }

        r = (pos_i - posArr[j]).norm();
        rho_i += mass * kern.Weight(r, smoothingLength);
        if (j < Start && pId < Start)
            rho_tmp += mass * kern.Weight(r, smoothingLength);
    }
    //if (tmp && pId < Start)
    //printf("%.3lf %.3lf %d\n", rho_i, rho_tmp, nbSize);
    rhoArr[pId] = rho_i;
}

template <typename TDataType>
DensitySummationMesh<TDataType>::DensitySummationMesh()
    : ComputeModule()
    , m_factor(Real(1))
{
    m_mass.setValue(Real(1));
    m_restDensity.setValue(Real(1000));
    m_smoothingLength.setValue(Real(0.011));

    attachField(&m_mass, "mass", "particle mass", false);
    attachField(&m_restDensity, "rest_density", "Reference density", false);
    attachField(&m_smoothingLength, "smoothing_length", "The smoothing length in SPH!", false);

    attachField(&m_position, "position", "Storing the particle positions!", false);
    attachField(&m_density, "density", "Storing the particle densities!", false);
    attachField(&m_neighborhood, "neighborhood", "Storing neighboring particles' ids!", false);
}

template <typename TDataType>
void DensitySummationMesh<TDataType>::compute()
{
    printf("%d\n", m_position.getElementCount());
    if (!m_position.isEmpty() && m_density.getElementCount() != m_position.getElementCount())
    {
        printf("%d\n", m_position.getElementCount());
        m_density.setElementCount(m_position.getElementCount());
    }
    compute(
        m_density.getValue(),
        m_position.getValue(),
        Tri.getValue(),
        TriPoint.getValue(),
        m_neighborhood.getValue(),
        m_neighborhoodTri.getValue(),
        m_smoothingLength.getValue(),
        m_mass.getValue(),
        sampling_distance.getValue(),
        use_mesh.getValue(),
        use_ghost.getValue(),
        Start.getValue());
}

template <typename TDataType>
void DensitySummationMesh<TDataType>::compute(DeviceArray<Real>& rho)
{

    compute(
        rho,
        m_position.getValue(),
        Tri.getValue(),
        TriPoint.getValue(),
        m_neighborhood.getValue(),
        m_neighborhoodTri.getValue(),
        m_smoothingLength.getValue(),
        m_mass.getValue(),
        sampling_distance.getValue(),
        use_mesh.getValue(),
        use_ghost.getValue(),
        Start.getValue());
}

template <typename TDataType>
void DensitySummationMesh<TDataType>::compute(
    DeviceArray<Real>&                     rho,
    DeviceArray<Coord>&                    pos,
    DeviceArray<TopologyModule::Triangle>& Tri,
    DeviceArray<Coord>&                    positionTri,
    NeighborList<int>&                     neighbors,
    NeighborList<int>&                     neighborsTri,
    Real                                   smoothingLength,
    Real                                   mass,
    Real                                   sampling_distance,
    int                                    use_mesh,
    int                                    use_ghost,
    int                                    Start)
{
    cuint pDims = cudaGridSize(rho.size(), BLOCK_SIZE);
    K_ComputeDensityMesh<Real, Coord><<<pDims, BLOCK_SIZE>>>(
        rho,
        pos,
        Tri,
        positionTri,
        neighbors,
        neighborsTri,
        smoothingLength,
        m_factor * mass,
        sampling_distance,
        use_mesh,
        use_ghost,
        Start);
    cuSynchronize();
}

template <typename TDataType>
bool DensitySummationMesh<TDataType>::initializeImpl()
{
    if (m_position.isEmpty())
    {
        // initialize the renormalization factor, ensuring rho to be rho_0 when particles are sampled at sampling distance
        Real d     = sampling_distance.getValue();
        Real H     = m_smoothingLength.getValue();
        Real rho_0 = m_restDensity.getValue();
        Real m     = m_mass.getValue();

        SpikyKernel<Real> kern;

        Real rho_e(0);
        int  half_res = H / d + 1;
        for (int i = -half_res; i <= half_res; i++)
            for (int j = -half_res; j <= half_res; j++)
                for (int k = -half_res; k <= half_res; k++)
                {
                    Real x = i * d;
                    Real y = j * d;
                    Real z = k * d;
                    Real r = sqrt(x * x + y * y + z * z);
                    rho_e += m * kern.Weight(r, H);
                }

        m_factor = rho_0 / rho_e;
        //printf("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ %.18lf from density\n", m_factor);
        return true;
    }
    if (!m_position.isEmpty() && m_density.isEmpty())
    {
        m_density.setElementCount(m_position.getElementCount());
    }

    if (!isAllFieldsReady())
    {
        std::cout << "Exception: " << std::string("DensitySummationMesh's fields are not fully initialized!") << "\n";
        return false;
    }

    printf("%d\n", m_position.getValue().size());

    compute(
        m_density.getValue(),
        m_position.getValue(),
        Tri.getValue(),
        TriPoint.getValue(),
        m_neighborhood.getValue(),
        m_neighborhoodTri.getValue(),
        m_smoothingLength.getValue(),
        m_mass.getValue(),
        sampling_distance.getValue(),
        use_mesh.getValue(),
        0,
        Start.getValue());

    auto rho = m_density.getReference();

    Reduction<Real>* pReduce = Reduction<Real>::Create(rho->size());

    Real maxRho = pReduce->maximum(rho->getDataPtr(), rho->size());

    m_factor = m_restDensity.getValue() / maxRho;

    delete pReduce;

    return true;
}
}  // namespace PhysIKA