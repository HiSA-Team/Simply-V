/* Auto-generated with create_config.py */
REGION_ALIAS("OPENSBI_MEMORY", DDR2);
__payload_offset = 0x200000;
__stack_top = ORIGIN(OPENSBI_MEMORY) + LENGTH(OPENSBI_MEMORY);
__payload_start = ORIGIN(OPENSBI_MEMORY) + __payload_offset;
