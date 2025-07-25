// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "gtest/gtest.h"

#include "flutter/impeller/geometry/matrix.h"

#include "flutter/impeller/geometry/geometry_asserts.h"
#include "impeller/geometry/constants.h"

namespace impeller {
namespace testing {

TEST(MatrixTest, Multiply) {
  Matrix x(0.0, 0.0, 0.0, 1.0,  //
           1.0, 0.0, 0.0, 1.0,  //
           0.0, 1.0, 0.0, 1.0,  //
           1.0, 1.0, 0.0, 1.0);
  Matrix translate = Matrix::MakeTranslation({10, 20, 0});
  Matrix result = translate * x;
  EXPECT_TRUE(MatrixNear(result, Matrix(10.0, 20.0, 0.0, 1.0,  //
                                        11.0, 20.0, 0.0, 1.0,  //
                                        10.0, 21.0, 0.0, 1.0,  //
                                        11.0, 21.0, 0.0, 1.0)));
}

TEST(MatrixTest, Equals) {
  Matrix x;
  Matrix y = x;
  EXPECT_TRUE(x.Equals(y));
}

TEST(MatrixTest, NotEquals) {
  Matrix x;
  Matrix y = x.Translate({1, 0, 0});
  EXPECT_FALSE(x.Equals(y));
}

TEST(MatrixTest, HasPerspective2D) {
  EXPECT_FALSE(Matrix().HasPerspective2D());

  auto test = [](int index, bool expect) {
    Matrix matrix;
    EXPECT_FALSE(matrix.HasPerspective2D());
    matrix.m[index] = 0.5f;
    EXPECT_EQ(matrix.HasPerspective2D(), expect) << "index: " << index;
  };

  // clang-format off
  test( 0, false);  test( 1, false);  test( 2, false);  test( 3, true);
  test( 4, false);  test( 5, false);  test( 6, false);  test( 7, true);
  test( 8, false);  test( 9, false);  test(10, false);  test(11, false);
  test(12, false);  test(13, false);  test(14, false);  test(15, true);
  // clang-format on
}

TEST(MatrixTest, HasPerspective) {
  EXPECT_FALSE(Matrix().HasPerspective());

  auto test = [](int index, bool expect) {
    Matrix matrix;
    EXPECT_FALSE(matrix.HasPerspective());
    matrix.m[index] = 0.5f;
    EXPECT_EQ(matrix.HasPerspective(), expect) << "index: " << index;
  };

  // clang-format off
  test( 0, false);  test( 1, false);  test( 2, false);  test( 3, true);
  test( 4, false);  test( 5, false);  test( 6, false);  test( 7, true);
  test( 8, false);  test( 9, false);  test(10, false);  test(11, true);
  test(12, false);  test(13, false);  test(14, false);  test(15, true);
  // clang-format on
}

TEST(MatrixTest, HasTranslation) {
  EXPECT_TRUE(Matrix::MakeTranslation({100, 100, 0}).HasTranslation());
  EXPECT_TRUE(Matrix::MakeTranslation({0, 100, 0}).HasTranslation());
  EXPECT_TRUE(Matrix::MakeTranslation({100, 0, 0}).HasTranslation());
  EXPECT_FALSE(Matrix().HasTranslation());
}

TEST(MatrixTest, IsTranslationOnly) {
  EXPECT_TRUE(Matrix::MakeTranslation({100, 100, 0}).IsTranslationOnly());
  EXPECT_TRUE(Matrix::MakeTranslation({100, 100, 0}).IsTranslationScaleOnly());
  EXPECT_TRUE(Matrix::MakeTranslation({0, 100, 0}).IsTranslationOnly());
  EXPECT_TRUE(Matrix::MakeTranslation({0, 100, 0}).IsTranslationScaleOnly());
  EXPECT_TRUE(Matrix::MakeTranslation({100, 0, 0}).IsTranslationOnly());
  EXPECT_TRUE(Matrix::MakeTranslation({100, 0, 0}).IsTranslationScaleOnly());
  EXPECT_TRUE(Matrix().IsTranslationOnly());
  EXPECT_TRUE(Matrix().IsTranslationScaleOnly());
}

TEST(MatrixTest, IsTranslationScaleOnly) {
  EXPECT_FALSE(Matrix::MakeScale({100, 100, 1}).IsTranslationOnly());
  EXPECT_TRUE(Matrix::MakeScale({100, 100, 1}).IsTranslationScaleOnly());
  EXPECT_FALSE(Matrix::MakeScale({1, 100, 1}).IsTranslationOnly());
  EXPECT_TRUE(Matrix::MakeScale({1, 100, 1}).IsTranslationScaleOnly());
  EXPECT_FALSE(Matrix::MakeScale({100, 1, 1}).IsTranslationOnly());
  EXPECT_TRUE(Matrix::MakeScale({100, 1, 1}).IsTranslationScaleOnly());
  EXPECT_TRUE(Matrix().IsTranslationOnly());
  EXPECT_TRUE(Matrix().IsTranslationScaleOnly());
}

TEST(MatrixTest, IsInvertibleGetDeterminant) {
  EXPECT_TRUE(Matrix().IsInvertible());
  EXPECT_NE(Matrix().GetDeterminant(), 0.0f);

  EXPECT_TRUE(Matrix::MakeTranslation({100, 100, 0}).IsInvertible());
  EXPECT_NE(Matrix::MakeTranslation({100, 100, 0}).GetDeterminant(), 0.0f);

  EXPECT_TRUE(Matrix::MakeScale({100, 100, 1}).IsInvertible());
  EXPECT_NE(Matrix::MakeScale({100, 100, 1}).GetDeterminant(), 0.0f);

  EXPECT_TRUE(Matrix::MakeRotationX(Degrees(30)).IsInvertible());
  EXPECT_NE(Matrix::MakeRotationX(Degrees(30)).GetDeterminant(), 0.0f);

  EXPECT_TRUE(Matrix::MakeRotationY(Degrees(30)).IsInvertible());
  EXPECT_NE(Matrix::MakeRotationY(Degrees(30)).GetDeterminant(), 0.0f);

  EXPECT_TRUE(Matrix::MakeRotationZ(Degrees(30)).IsInvertible());
  EXPECT_NE(Matrix::MakeRotationZ(Degrees(30)).GetDeterminant(), 0.0f);

  EXPECT_FALSE(Matrix::MakeScale({0, 1, 1}).IsInvertible());
  EXPECT_EQ(Matrix::MakeScale({0, 1, 1}).GetDeterminant(), 0.0f);
  EXPECT_FALSE(Matrix::MakeScale({1, 0, 1}).IsInvertible());
  EXPECT_EQ(Matrix::MakeScale({1, 0, 1}).GetDeterminant(), 0.0f);
  EXPECT_FALSE(Matrix::MakeScale({1, 1, 0}).IsInvertible());
  EXPECT_EQ(Matrix::MakeScale({1, 1, 0}).GetDeterminant(), 0.0f);
}

TEST(MatrixTest, IsFinite) {
  EXPECT_TRUE(Matrix().IsFinite());

  EXPECT_TRUE(Matrix::MakeTranslation({100, 100, 0}).IsFinite());
  EXPECT_TRUE(Matrix::MakeScale({100, 100, 1}).IsFinite());

  EXPECT_TRUE(Matrix::MakeRotationX(Degrees(30)).IsFinite());
  EXPECT_TRUE(Matrix::MakeRotationY(Degrees(30)).IsFinite());
  EXPECT_TRUE(Matrix::MakeRotationZ(Degrees(30)).IsFinite());

  EXPECT_TRUE(Matrix::MakeScale({0, 1, 1}).IsFinite());
  EXPECT_TRUE(Matrix::MakeScale({1, 0, 1}).IsFinite());
  EXPECT_TRUE(Matrix::MakeScale({1, 1, 0}).IsFinite());

  for (int i = 0; i < 16; i++) {
    {
      Matrix matrix;
      ASSERT_TRUE(matrix.IsFinite());
      matrix.m[i] = std::numeric_limits<Scalar>::infinity();
      ASSERT_FALSE(matrix.IsFinite());
    }

    {
      Matrix matrix;
      ASSERT_TRUE(matrix.IsFinite());
      matrix.m[i] = -std::numeric_limits<Scalar>::infinity();
      ASSERT_FALSE(matrix.IsFinite());
    }

    {
      Matrix matrix;
      ASSERT_TRUE(matrix.IsFinite());
      matrix.m[i] = -std::numeric_limits<Scalar>::quiet_NaN();
      ASSERT_FALSE(matrix.IsFinite());
    }
  }
}

TEST(MatrixTest, IsAligned2D) {
  EXPECT_TRUE(Matrix().IsAligned2D());
  EXPECT_TRUE(Matrix::MakeScale({1.0f, 1.0f, 2.0f}).IsAligned2D());

  auto test = [](int index, bool expect) {
    Matrix matrix;
    EXPECT_TRUE(matrix.IsAligned2D());
    matrix.m[index] = 0.5f;
    EXPECT_EQ(matrix.IsAligned2D(), expect) << "index: " << index;
  };

  // clang-format off
  test( 0, true);   test( 1, false);  test( 2, true);   test( 3, false);
  test( 4, false);  test( 5, true);   test( 6, true);   test( 7, false);
  test( 8, true);   test( 9, true);   test(10, true);   test(11, true);
  test(12, true);   test(13, true);   test(14, true);   test(15, false);
  // clang-format on

  // True for quadrant rotations from -250 to +250 full circles
  for (int i = -1000; i < 1000; i++) {
    Degrees d = Degrees(i * 90);
    Matrix matrix = Matrix::MakeRotationZ(Degrees(d));
    EXPECT_TRUE(matrix.IsAligned2D()) << "degrees: " << d.degrees;
  }

  // False for half degree rotations from -999.5 to +1000.5 degrees
  for (int i = -1000; i < 1000; i++) {
    Degrees d = Degrees(i + 0.5f);
    Matrix matrix = Matrix::MakeRotationZ(Degrees(d));
    EXPECT_FALSE(matrix.IsAligned2D()) << "degrees: " << d.degrees;
  }
}

TEST(MatrixTest, IsAligned) {
  EXPECT_TRUE(Matrix().IsAligned());
  EXPECT_TRUE(Matrix::MakeScale({1.0f, 1.0f, 2.0f}).IsAligned());

  // Begin Legacy tests transferred over from geometry_unittests.cc
  {
    auto m = Matrix::MakeTranslation({1, 2, 3});
    bool result = m.IsAligned();
    ASSERT_TRUE(result);
  }

  {
    auto m = Matrix::MakeRotationZ(Degrees{123});
    bool result = m.IsAligned();
    ASSERT_FALSE(result);
  }
  // End Legacy tests transferred over from geometry_unittests.cc

  auto test = [](int index, bool expect) {
    Matrix matrix;
    EXPECT_TRUE(matrix.IsAligned());
    matrix.m[index] = 0.5f;
    EXPECT_EQ(matrix.IsAligned(), expect) << "index: " << index;
  };

  // clang-format off
  test( 0, true);   test( 1, false);  test( 2, false);  test( 3, false);
  test( 4, false);  test( 5, true);   test( 6, false);  test( 7, false);
  test( 8, false);  test( 9, false);  test(10, true);   test(11, false);
  test(12, true);   test(13, true);   test(14, true);   test(15, false);
  // clang-format on

  // True for quadrant rotations from -250 to +250 full circles
  for (int i = -1000; i < 1000; i++) {
    Degrees d = Degrees(i * 90);
    Matrix matrix = Matrix::MakeRotationZ(Degrees(d));
    EXPECT_TRUE(matrix.IsAligned()) << "degrees: " << d.degrees;
  }

  // False for half degree rotations from -999.5 to +1000.5 degrees
  for (int i = -1000; i < 1000; i++) {
    Degrees d = Degrees(i + 0.5f);
    Matrix matrix = Matrix::MakeRotationZ(Degrees(d));
    EXPECT_FALSE(matrix.IsAligned()) << "degrees: " << d.degrees;
  }
}

TEST(MatrixTest, TransformHomogenous) {
  Matrix matrix = Matrix::MakeColumn(
      // clang-format off
       2.0f,  3.0f,  5.0f,  7.0f,
      11.0f, 13.0f, 17.0f, 19.0f,
      23.0f, 29.0f, 31.0f, 37.0f,
      41.0f, 43.0f, 47.0f, 53.0f
      // clang-format on
  );
  EXPECT_EQ(matrix.TransformHomogenous({1.0f, -1.0f}),
            Vector3(32.0f, 33.0f, 41.0f));
}

TEST(MatrixTest, GetMaxBasisXYNegativeScale) {
  Matrix m = Matrix::MakeScale({-2, 1, 1});

  EXPECT_EQ(m.GetMaxBasisLengthXY(), 2);

  m = Matrix::MakeScale({1, -3, 1});

  EXPECT_EQ(m.GetMaxBasisLengthXY(), 3);
}

// Verifies a translate scale matrix doesn't need to compute sqrt(pow(scale, 2))
TEST(MatrixTest, GetMaxBasisXYWithLargeAndSmallScalingFactor) {
  Matrix m = Matrix::MakeScale({2.625e+20, 2.625e+20, 1});
  EXPECT_NEAR(m.GetMaxBasisLengthXY(), 2.625e+20, 1e+20);

  m = Matrix::MakeScale({2.625e-20, 2.625e-20, 1});
  EXPECT_NEAR(m.GetMaxBasisLengthXY(), 2.625e-20, 1e-20);
}

TEST(MatrixTest, GetMaxBasisXYWithLargeAndSmallScalingFactorNonScaleTranslate) {
  Matrix m = Matrix::MakeScale({2.625e+20, 2.625e+20, 1});
  m.e[0][1] = 2;

  EXPECT_TRUE(std::isinf(m.GetMaxBasisLengthXY()));
}

TEST(MatrixTest, TranslateWithPerspective) {
  Matrix m = Matrix::MakeRow(1.0, 0.0, 0.0, 10.0,  //
                             0.0, 1.0, 0.0, 20.0,  //
                             0.0, 0.0, 1.0, 0.0,   //
                             0.0, 2.0, 0.0, 30.0);
  Matrix result = m.Translate({100, 200});
  EXPECT_TRUE(MatrixNear(result, Matrix::MakeRow(1.0, 0.0, 0.0, 110.0,  //
                                                 0.0, 1.0, 0.0, 220.0,  //
                                                 0.0, 0.0, 1.0, 0.0,    //
                                                 0.0, 2.0, 0.0, 430.0)));
}

TEST(MatrixTest, MakeScaleTranslate) {
  EXPECT_TRUE(MatrixNear(
      Matrix::MakeTranslateScale({1, 1, 1.0 / 1024}, {10, 10, 1.0 / 1024}),
      Matrix::MakeTranslation({10, 10, 1.0 / 1024}) *
          Matrix::MakeScale({1, 1, 1.0 / 1024})));

  EXPECT_TRUE(MatrixNear(
      Matrix::MakeTranslateScale({2, 2, 2}, {10, 10, 0}),
      Matrix::MakeTranslation({10, 10, 0}) * Matrix::MakeScale({2, 2, 2})));

  EXPECT_TRUE(MatrixNear(
      Matrix::MakeTranslateScale({0, 0, 0}, {0, 0, 0}),
      Matrix::MakeTranslation({0, 0, 0}) * Matrix::MakeScale({0, 0, 0})));
}

TEST(MatrixTest, To3x3) {
  Matrix x(1.0, 0.0, 4.0, 0.0,    //
           0.0, 1.0, 4.0, 0.0,    //
           6.0, 5.0, 111.0, 7.0,  //
           0.0, 0.0, 9.0, 1.0);

  EXPECT_TRUE(MatrixNear(x.To3x3(), Matrix()));
}

TEST(MatrixTest, MinMaxScales2D) {
  // The GetScales2D() method is allowed to return the scales in any
  // order so we need to take special care in verifying the return
  // value to test them in either order.
  auto check_pair = [](const Matrix& matrix, Scalar scale1, Scalar scale2) {
    auto pair = matrix.GetScales2D();
    EXPECT_TRUE(pair.has_value())
        << "Scales: " << scale1 << ", " << scale2 << ", " << matrix;
    if (ScalarNearlyEqual(pair->first, scale1)) {
      EXPECT_FLOAT_EQ(pair->first, scale1) << matrix;
      EXPECT_FLOAT_EQ(pair->second, scale2) << matrix;
    } else {
      EXPECT_FLOAT_EQ(pair->first, scale2) << matrix;
      EXPECT_FLOAT_EQ(pair->second, scale1) << matrix;
    }
  };

  for (int i = 1; i < 10; i++) {
    Scalar xScale = static_cast<Scalar>(i);
    for (int j = 1; j < 10; j++) {
      Scalar yScale = static_cast<Scalar>(j);
      Scalar minScale = std::min(xScale, yScale);
      Scalar maxScale = std::max(xScale, yScale);

      {
        // Simple scale
        Matrix matrix = Matrix::MakeScale({xScale, yScale, 1.0f});
        EXPECT_TRUE(matrix.GetMinScale2D().has_value());
        EXPECT_TRUE(matrix.GetMaxScale2D().has_value());
        EXPECT_FLOAT_EQ(matrix.GetMinScale2D().value_or(-1.0f), minScale);
        EXPECT_FLOAT_EQ(matrix.GetMaxScale2D().value_or(-1.0f), maxScale);
        check_pair(matrix, xScale, yScale);
      }

      {
        // Simple scale with Z scale
        Matrix matrix = Matrix::MakeScale({xScale, yScale, 5.0f});
        EXPECT_TRUE(matrix.GetMinScale2D().has_value());
        EXPECT_TRUE(matrix.GetMaxScale2D().has_value());
        EXPECT_FLOAT_EQ(matrix.GetMinScale2D().value_or(-1.0f), minScale);
        EXPECT_FLOAT_EQ(matrix.GetMaxScale2D().value_or(-1.0f), maxScale);
        check_pair(matrix, xScale, yScale);
      }

      {
        // Simple scale + translate
        Matrix matrix = Matrix::MakeTranslateScale({xScale, yScale, 1.0f},
                                                   {10.0f, 15.0f, 2.0f});
        EXPECT_TRUE(matrix.GetMinScale2D().has_value());
        EXPECT_TRUE(matrix.GetMaxScale2D().has_value());
        EXPECT_FLOAT_EQ(matrix.GetMinScale2D().value_or(-1.0f), minScale);
        EXPECT_FLOAT_EQ(matrix.GetMaxScale2D().value_or(-1.0f), maxScale);
        check_pair(matrix, xScale, yScale);
      }

      for (int d = 45; d < 360; d += 45) {
        {
          // Rotation * Scale
          Matrix matrix = Matrix::MakeScale({xScale, yScale, 1.0f}) *
                          Matrix::MakeRotationZ(Degrees(d));
          EXPECT_TRUE(matrix.GetMinScale2D().has_value());
          EXPECT_TRUE(matrix.GetMaxScale2D().has_value());
          EXPECT_FLOAT_EQ(matrix.GetMinScale2D().value_or(-1.0f), minScale);
          EXPECT_FLOAT_EQ(matrix.GetMaxScale2D().value_or(-1.0f), maxScale);
          check_pair(matrix, xScale, yScale);
        }

        {
          // Scale * Rotation
          Matrix matrix = Matrix::MakeRotationZ(Degrees(d)) *
                          Matrix::MakeScale({xScale, yScale, 1.0f});
          EXPECT_TRUE(matrix.GetMinScale2D().has_value());
          EXPECT_TRUE(matrix.GetMaxScale2D().has_value());
          EXPECT_FLOAT_EQ(matrix.GetMinScale2D().value_or(-1.0f), minScale);
          EXPECT_FLOAT_EQ(matrix.GetMaxScale2D().value_or(-1.0f), maxScale);
          check_pair(matrix, xScale, yScale);
        }
      }

      {
        // Scale + PerspectiveX (returns invalid values)
        Matrix matrix = Matrix::MakeScale({xScale, yScale, 1.0f});
        matrix.m[3] = 0.1;
        EXPECT_FALSE(matrix.GetMinScale2D().has_value());
        EXPECT_FALSE(matrix.GetMaxScale2D().has_value());
        EXPECT_FALSE(matrix.GetScales2D().has_value());
      }

      {
        // Scale + PerspectiveY (returns invalid values)
        Matrix matrix = Matrix::MakeScale({xScale, yScale, 1.0f});
        matrix.m[7] = 0.1;
        EXPECT_FALSE(matrix.GetMinScale2D().has_value());
        EXPECT_FALSE(matrix.GetMaxScale2D().has_value());
        EXPECT_FALSE(matrix.GetScales2D().has_value());
      }

      {
        // Scale + PerspectiveZ (Z ignored; returns actual scales)
        Matrix matrix = Matrix::MakeScale({xScale, yScale, 1.0f});
        matrix.m[11] = 0.1;
        EXPECT_TRUE(matrix.GetMinScale2D().has_value());
        EXPECT_TRUE(matrix.GetMaxScale2D().has_value());
        EXPECT_FLOAT_EQ(matrix.GetMinScale2D().value_or(-1.0f), minScale);
        EXPECT_FLOAT_EQ(matrix.GetMaxScale2D().value_or(-1.0f), maxScale);
        check_pair(matrix, xScale, yScale);
      }

      {
        // Scale + PerspectiveW (returns invalid values)
        Matrix matrix = Matrix::MakeScale({xScale, yScale, 1.0f});
        matrix.m[15] = 0.1;
        EXPECT_FALSE(matrix.GetMinScale2D().has_value());
        EXPECT_FALSE(matrix.GetMaxScale2D().has_value());
        EXPECT_FALSE(matrix.GetScales2D().has_value());
      }
    }
  }
}

}  // namespace testing
}  // namespace impeller
