void main()
{
	vec2 size = vec2(textureSize(InputTexture, 0));
	float px = max(2.0, floor(size.y / 330.0));
	vec2 cell = floor(TexCoord * size / px);
	vec2 uv = (cell + 0.5) * px / size;
	vec3 c = texture(InputTexture, uv).rgb;
	// warm, a bit more saturated, soft contrast
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 1.18);
	c *= vec3(1.04, 1.0, 0.95);
	c = mix(c, smoothstep(0.0, 1.0, c), 0.25);
	// gentle vignette
	vec2 d = TexCoord - 0.5;
	c *= 1.0 - dot(d, d) * 0.35;
	FragColor = vec4(c, 1.0);
}
