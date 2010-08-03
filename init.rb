# Include hook code here
ActiveRecord::Base.class_eval { extend ModelCacher }
