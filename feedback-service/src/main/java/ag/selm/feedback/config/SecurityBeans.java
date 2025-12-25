package ag.selm.feedback.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.web.server.SecurityWebFilterChain;
import org.springframework.security.web.server.context.NoOpServerSecurityContextRepository;

@Configuration
public class SecurityBeans {

    @Bean
    public SecurityWebFilterChain securityWebFilterChain(ServerHttpSecurity http) {
        return http
                .authorizeExchange(ex -> ex
                        // Swagger / OpenAPI
                        .pathMatchers("/webjars/**", "/v3/api-docs/**", "/swagger-ui.html", "/swagger-ui/**").permitAll()

                        // Kubernetes probes must be unauthenticated (kubelet не умеет добавлять токены)
                        .pathMatchers("/actuator/health/liveness", "/actuator/health/readiness").permitAll()

                        // Остальные actuator эндпоинты — только под metrics scope
                        .pathMatchers("/actuator/**").hasAuthority("SCOPE_metrics")

                        // Дальше — как было: всё остальное требует аутентификацию
                        .anyExchange().authenticated()
                )
                .csrf(ServerHttpSecurity.CsrfSpec::disable)
                .securityContextRepository(NoOpServerSecurityContextRepository.getInstance())
                .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
                .oauth2Client(Customizer.withDefaults())
                .build();
    }
}
