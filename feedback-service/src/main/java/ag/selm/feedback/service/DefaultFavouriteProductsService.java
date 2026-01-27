package ag.selm.feedback.service;

import ag.selm.feedback.entity.FavouriteProduct;
import ag.selm.feedback.repository.FavouriteProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class DefaultFavouriteProductsService implements FavouriteProductsService {

    private final FavouriteProductRepository favouriteProductRepository;

    @Override
    public Mono<FavouriteProduct> addProductToFavourites(int productId, String userId) {
        FavouriteProduct entity = new FavouriteProduct(UUID.randomUUID(), productId, userId);
        return this.favouriteProductRepository.save(entity)
                .doOnSuccess(saved ->
                        log.info("Favourite added: userId={}, productId={}, favouriteId={}",
                                saved.getUserId(), saved.getProductId(), saved.getId()))
                .doOnError(e ->
                        log.error("Favourite add failed: userId={}, productId={}",
                                userId, productId, e));
    }

    @Override
    public Mono<Void> removeProductFromFavourites(int productId, String userId) {
        return this.favouriteProductRepository.deleteByProductIdAndUserId(productId, userId)
                .doOnSuccess(v ->
                        log.info("Favourite removed: userId={}, productId={}", userId, productId))
                .doOnError(e ->
                        log.error("Favourite remove failed: userId={}, productId={}",
                                userId, productId, e));
    }

    @Override
    public Mono<FavouriteProduct> findFavouriteProductByProduct(int productId, String userId) {
        return this.favouriteProductRepository.findByProductIdAndUserId(productId, userId);
    }

    @Override
    public Flux<FavouriteProduct> findFavouriteProducts(String userId) {
        return this.favouriteProductRepository.findAllByUserId(userId);
    }
}
