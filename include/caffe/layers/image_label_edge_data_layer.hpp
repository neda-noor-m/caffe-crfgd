#ifndef CAFFE_IMAGE_LABEL_EDGE_DATA_LAYER_H
#define CAFFE_IMAGE_LABEL_EDGE_DATA_LAYER_H

#include <random>
#include <vector>

#include <opencv2/core/core.hpp>

#include "caffe/blob.hpp"
#include "caffe/data_transformer.hpp"
#include "caffe/internal_thread.hpp"
#include "caffe/layer.hpp"
#include "caffe/layers/base_data_layer.hpp"
#include "caffe/proto/caffe.pb.h"
#include "caffe/util/db.hpp"

namespace caffe {

template<typename Dtype>
class ImageLabelEdgeDataLayer : public BasePrefetchingData4Layer<Dtype> {
 public:
  explicit ImageLabelEdgeDataLayer(const LayerParameter &param);

  virtual ~ImageLabelEdgeDataLayer();

  virtual void DataLayerSetUp(const vector<Blob<Dtype> *> &bottom,
                              const vector<Blob<Dtype> *> &top);

  // DataLayer uses DataReader instead for sharing for parallelism
  virtual inline bool ShareInParallel() const { return false; }

  virtual inline const char *type() const { return "ImageLabelEdgeData"; }

  virtual inline int ExactNumBottomBlobs() const { return 0; }

  virtual inline int ExactNumTopBlobs() const { return -1; }

  virtual inline int MaxTopBlobs() const { return 6; }

  virtual inline int MinTopBlobs() const { return 5; }

 protected:
  shared_ptr<Caffe::RNG> prefetch_rng_;

  virtual void ShuffleImages();

  virtual void SampleScale(cv::Mat *image, cv::Mat *label1, cv::Mat *label2, cv::Mat *label3, cv::Mat *label4);

  virtual void load_batch(Batch4<Dtype>* batch);

  vector<std::string> image_lines_;
  vector<std::string> label1_lines_;
  vector<std::string> label2_lines_;
  vector<std::string> label3_lines_;
  vector<std::string> label4_lines_;
  int lines_id_;

  Blob<Dtype> transformed_label1_;
  Blob<Dtype> transformed_label2_;
  Blob<Dtype> transformed_label3_;
  Blob<Dtype> transformed_label4_;

  int label_margin_h_;
  int label_margin_w_;

  bool hsv_noise_;
  int h_noise_;
  int s_noise_;
  int v_noise_;

  bool pad_centre_;

  std::mt19937 *rng_;
};

} // namspace caffe

#endif //CAFFE_IMAGE_LABEL_DATA_LAYER_H
