import os

# SoC Profile
soc_profile = os.environ["SOC_CONFIG"]
# Paths
configs_root = os.path.join(os.environ["CONFIG_ROOT"], "configs")
configs_common = os.path.join(configs_root, "common")
configs_embedded = os.path.join(configs_root, "embedded")
configs_hpc = os.path.join(configs_root, "hpc")

sw_soc_common = os.path.join(os.environ["SW_SOC_ROOT"], "common")


