import Image, { type ImageProps } from 'next/image';
import { assetPath } from '@/lib/assets';

export default function PortfolioImage({ src, alt, ...props }: ImageProps) {
  return <Image {...props} alt={alt} src={typeof src === 'string' ? assetPath(src) : src} />;
}
