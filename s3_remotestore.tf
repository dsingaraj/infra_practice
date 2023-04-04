/* resource aws_s3_bucket "terraform_states3_bucket"{
    bucket="terraformstateremotestoreishods27"

    versioning {
      enabled=true      
    }

    lifecycle {
      prevent_destroy = true
    }
}  */