#include "HeightFieldNode.h"
#include "Framework/Topology/HeightField.h"
#include "ShallowWaterEquationModel.h"
#include "IO\Image_IO\image.h"
#include "IO\Image_IO\png_io.h"

namespace PhysIKA
{
	IMPLEMENT_CLASS_1(HeightFieldNode, TDataType)

	template<typename TDataType>
	HeightFieldNode<TDataType>::HeightFieldNode(std::string name = "default")
		: Node(name)
	{
		auto swe = this->template setNumericalModel<ShallowWaterEquationModel<TDataType>>("swe");
		this->setNumericalModel(swe);
		SWEconnect();
		
		m_height_field = std::make_shared<HeightField<TDataType>>();
		this->setTopologyModule(m_height_field);
	}

	template<typename TDataType>
	void HeightFieldNode<TDataType>::SWEconnect()
	{
		auto swe = this->getModule<ShallowWaterEquationModel<TDataType>>("swe");
		this->currentPosition()->connect(&(swe->m_position));
		
		this->currentVelocity()->connect(&(swe->m_velocity));
		this->normal.connect(&(swe->normal));

		this->isBound.connect(&(swe->isBound));
		this->solid.connect(&(swe->solid));

		swe->setDistance(distance);
		swe->setRelax(relax);
		swe->setZcount(zcount);
	}

	template<typename TDataType>
	bool HeightFieldNode<TDataType>::initialize()
	{
		return Node::initialize();
	}

	//template<typename Real, typename Coord>
	__global__ void InitNeighbor(
		NeighborList<int> neighbors,
		int zcount,
		int xcount)
	{
		int i = threadIdx.x + (blockIdx.x * blockDim.x);
		if (i >= neighbors.size()) return;
		if(i%zcount==0)
			neighbors.setElement(i, 0, - 1);
		else
			neighbors.setElement(i, 0, i - 1);
		if((i+1)%zcount == 0)
			neighbors.setElement(i, 1, -1);
		else
			neighbors.setElement(i, 1, i + 1);

		neighbors.setElement(i, 2, i - zcount);
		neighbors.setElement(i, 3, i + zcount);
	}

	template<typename TDataType>
	void HeightFieldNode<TDataType>::loadHeightFieldParticles(Coord lo, Coord hi, int pixels, Real slope)
	{
		std::vector<Coord> vertList;
		std::vector<Coord> normalList;

		float height, e = 2.71828;
		Real distance = (hi[2] - lo[2]) / (pixels - 1);
		nx = (hi[0] - lo[0]) / distance;
		nz = (hi[2] - lo[2]) / distance;
		float xcenter = (hi[0] - lo[0]) / 2, zcenter = (hi[2] - lo[2]) / 2;
		//float xcenter = 0.1, zcenter = 0.8;
		Real x = lo[0];
		for (int i = 0; i < pixels; i++)
		{
			Real z = lo[2];
			for (int j = 0; j < pixels; j++)
			{
				height =  0.3 + slope * pow(e, -(pow(x - xcenter, 2) + pow(z - zcenter, 2)) * 100);
				Coord p = Coord(x, 0, z);
				vertList.push_back(Coord(x, height + lo[1], z));
				//vertList.push_back(Coord(x, lo[1], z));
				normalList.push_back(Coord(0, 1, 0));
				z += distance;
			}
			x += distance;
		}
		//int zcount = int((hi[2] - lo[2]) / distance) + 1;
		/*vertList[vertList.size()-1][1] = 1;
		vertList[vertList.size()-zcount*2][1] = 1;
		vertList[0][1] = 1;
		vertList[zcount-2][1] = 1;		
		*/
		/*vertList[vertList.size()-1][1] = 1;
		vertList[vertList.size()-zcount][1] = 1;
		vertList[0][1] = 1;
		vertList[zcount-1][1] = 1;*/

		this->currentPosition()->setElementCount(vertList.size());
		//printf("vertList size is %d\n", vertList.size());
		Function1Pt::copy(this->currentPosition()->getValue(), vertList);

		Image *image = new Image;
		std::string filename1 = "F:\\�½��ļ���\\���ĵ�һѧ��\\swe\\1.png";
		PngIO::load(filename1, image);
		//string filename2 = "F:\\�½��ļ���\\���ĵ�һѧ��\\swe\\2.png";
		//PngIO::save(filename2, image);
		
		this->currentVelocity()->setElementCount(vertList.size());
		Function1Pt::copy(this->currentVelocity()->getValue(), vertList);

		vertList.clear();
		normalList.clear();
	}

	template<typename TDataType>
	//void HeightFieldNode<TDataType>::loadParticles(Coord lo, Coord hi, Real distance,Real slope, Real relax)
	//�ö�������ʾ��ֱ��һЩ
	void HeightFieldNode<TDataType>::loadParticles(Coord lo, Coord hi, int pixels,Real slope, Real relax)
	{
		Real distance = (hi[2] - lo[2]) / (pixels-1);
		loadHeightFieldParticles(lo, hi, pixels, slope);
		this->distance = distance;
		this->relax = relax;
		std::vector<Coord> solidList;
		std::vector<Coord> normals;
		std::vector<int>  isbound;
		float height, e = 2.71828;
		float xcenter = (hi[0] - lo[0]) / 2, zcenter = (hi[2] - lo[2]) / 2;
		Real x = lo[0], z = lo[2];
		for (int i = 0; i < pixels; i++) 
		{
			Real z = lo[2];
			for (int j = 0;j < pixels; j++)
			{
				height = 0.2+slope * pow(e, -(pow(x - xcenter, 2) + pow(z - zcenter, 2)) * 100);
				//height = z*0.2;
				if (z + distance > hi[2] || x + distance > hi[0] || x == lo[0] || z == lo[2])
					isbound.push_back(1);
				else
					isbound.push_back(0);
				//solidList.push_back(Coord(x, lo[1] + height, z));
				solidList.push_back(Coord(x, lo[1], z));
				normals.push_back(Coord(0, 1, 0));
				z += distance;
			}
			//printf("%f,\n", x);
			x += distance;
		}
		xcount = pixels;
		zcount = pixels;

		solid.setElementCount(solidList.size());
		Function1Pt::copy(solid.getValue(), solidList);

		isBound.setElementCount(solidList.size());
		Function1Pt::copy(isBound.getValue(), isbound);

		normal.setElementCount(solidList.size());
		Function1Pt::copy(normal.getValue(), normals);

		zcount = solidList.size() / xcount;

		printf("distance si %f ,zcount is %d, xcount is %d\n",distance, zcount, xcount);
		solidList.clear();
		isbound.clear();
		normals.clear();
		DeviceArrayField<Coord> pos = *(this->currentPosition());
		SWEconnect();

		this->updateTopology();
	}

	//template<typename TDataType>
	//void HeightFieldNode<TDataType>::loadParticlesFromImage(std::string &filename, Real distance, Real relax)
	//{
	//	Image image;
	//	if (ImageIO::load(filename, image) == false)
	//		return;

	//}
	template<typename TDataType>
	HeightFieldNode<TDataType>::~HeightFieldNode()
	{
	}
	template<typename TDataType>
	void HeightFieldNode<TDataType>::advance(Real dt)
	{
		auto nModel = this->getNumericalModel();
		nModel->step(dt);
	}

	template<typename Real, typename Coord>
	__global__ void SetupHeights(
		DeviceArray2D<Real> height, 
		DeviceArray<Coord> pts)
	{
		int i = threadIdx.x + blockIdx.x * blockDim.x;
		int j = threadIdx.y + blockIdx.y * blockDim.y;

		if (i < height.Nx() && j < height.Ny())
		{
			int id = i + j * (height.Nx() + 1);

			height(i, j) = pts[id][1];
		}
	}

	template<typename TDataType>
	void HeightFieldNode<TDataType>::updateTopology()
	{
		if (!this->currentPosition()->isEmpty())
		{
			int num = this->currentPosition()->getElementCount();
			auto& pts = this->currentPosition()->getValue();

			m_height_field->setSpace(0.005, 0.005);
			auto& heights = m_height_field->getHeights();

			if (nx != heights.Nx() || nz != heights.Ny())
			{
				heights.resize(nx, nz);
			}

			uint3 total_size;
			total_size.x = nx;
			total_size.y = nz;
			total_size.z = 1;

			//ti++;

			cuExecute3D(total_size, SetupHeights,
				heights,
				pts);
		}
	}

}